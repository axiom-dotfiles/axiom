#!/usr/bin/env bash
#
# Restarts axiom: the "Restart shell" bind on every compositor runs it.
# Ends every axiom of this install on this display, then starts one.
#
# `qs kill` alone can't do it: it ends one instance (the oldest, which may
# already be on its way out) and returns before it has quit, so a bind
# firing twice, or pressed again while axiom starts, leaves two running,
# and every later restart keeps that count. Here:
#   - a lock per display drops a restart fired while one runs
#   - every instance is asked to quit (SIGTERM), and killed if it hasn't
#     within 3 s
#   - one is started with -n, and the lock is held until it shows in
#     `qs list`, so a restart right after can't start a second
# The shell checks at start too (InstanceManager): the newest axiom on a
# display ends the others.
#
# Usage: restart.sh
#
set -u

repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
display="${WAYLAND_DISPLAY:-${DISPLAY:-none}}"
lock="${XDG_RUNTIME_DIR:-/tmp}/axiom-restart-${display//\//_}.lock"

exec 9>"$lock"
flock -n 9 || exit 0

# The pids of this install's running instances on this display
pids() {
  qs list -p "$repo" -j 2>/dev/null | grep -o '"pid": *[0-9]*' | grep -o '[0-9]*$'
}

alive() {
  local pid
  for pid in "$@"; do
    kill -0 "$pid" 2>/dev/null && return 0
  done
  return 1
}

mapfile -t running < <(pids)
if ((${#running[@]})); then
  kill -TERM "${running[@]}" 2>/dev/null
  for _ in $(seq 30); do
    alive "${running[@]}" || break
    sleep 0.1
  done
  alive "${running[@]}" && kill -KILL "${running[@]}" 2>/dev/null
fi

# fd 9 closed for the shell, or it would hold the lock for its lifetime
qs -p "$repo" -n -d 9>&- >/dev/null 2>&1
for _ in $(seq 100); do
  [[ -n "$(pids)" ]] && break
  sleep 0.1
done
