#!/usr/bin/env bash
# Print what a bug report needs to know about this machine, ready to paste
# into the bug report form's "System info" field: axiom's version (a clone's
# git description, or a package's), the axiom binary's and whether it runs
# here, whether the config loads, Quickshell's, the compositor and its
# version, the distribution, the config's version and compositor mode, and
# how many monitors are on. Nothing personal: no monitor names, no paths.
#
#   scripts/bug_info.sh

set -uo pipefail

repo=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
config="${XDG_CONFIG_HOME:-$HOME/.config}/axiom/config.json"

has() { command -v "$1" >/dev/null 2>&1; }

if [[ -f "$repo/.packaged" ]]; then
  axiom="package $(<"$repo/.packaged")"
elif has git && git -C "$repo" rev-parse --git-dir >/dev/null 2>&1; then
  axiom="clone $(git -C "$repo" describe --tags --always --dirty 2>/dev/null)"
  branch=$(git -C "$repo" branch --show-current 2>/dev/null)
  [[ -n "$branch" && "$branch" != main ]] && axiom+=" (branch $branch)"
else
  axiom="unknown (neither a clone nor a package)"
fi

# The binary: the running daemon's (what the shell really runs), else the
# one on PATH, else where install.sh puts it
pid=$(pgrep -f '(^|/)axiom run( |$)' 2>/dev/null | head -1)
if [[ -n "$pid" && -x "/proc/$pid/exe" ]]; then
  bin="/proc/$pid/exe" state="running"
else
  bin=$(command -v axiom 2>/dev/null || echo "${XDG_BIN_HOME:-$HOME/.local/bin}/axiom") state="not running"
fi
if [[ -x "$bin" ]]; then
  binary="$("$bin" version 2>/dev/null | head -1), $state"
  # ok, blocked (config.json doesn't load), …: never the path
  config_state=$("$bin" config status 2>/dev/null | head -1 | cut -d' ' -f1)
else
  binary="not found"
fi

quickshell=$(qs --version 2>/dev/null | head -1)

compositor="${XDG_CURRENT_DESKTOP:-unknown}"
monitors="unknown"
if [[ -n "${HYPRLAND_INSTANCE_SIGNATURE:-}" ]] && has hyprctl; then
  compositor=$(hyprctl version 2>/dev/null | head -1)
  has jq && monitors=$(hyprctl monitors -j 2>/dev/null | jq length 2>/dev/null)
elif [[ -n "${NIRI_SOCKET:-}" ]] && has niri; then
  compositor=$(niri --version 2>/dev/null | head -1)
  has jq && monitors=$(niri msg -j outputs 2>/dev/null | jq '[.[] | select(.logical != null)] | length' 2>/dev/null)
elif [[ -n "${SWAYSOCK:-}" ]] && has swaymsg; then
  compositor=$(swaymsg -t get_version -r 2>/dev/null | jq -r '"sway " + .human_readable' 2>/dev/null || echo sway)
  has jq && monitors=$(swaymsg -t get_outputs -r 2>/dev/null | jq '[.[] | select(.active)] | length' 2>/dev/null)
fi

distro=$(. /etc/os-release 2>/dev/null && echo "${PRETTY_NAME:-$ID}")

if [[ ! -f "$config" ]]; then
  config_info="missing"
elif ! has jq; then
  config_info="present (jq not installed)"
elif ! config_info=$(jq -r '"format \(.format // 1), version \(.version // "?"), compositor mode \(.Compositor.mode // "detached")"' "$config" 2>/dev/null); then
  config_info="invalid JSON"
fi

printf 'axiom:      %s\n' "$axiom"
printf 'Binary:     %s\n' "$binary"
printf 'Quickshell: %s\n' "${quickshell:-not found}"
printf 'Compositor: %s\n' "${compositor:-unknown}"
printf 'Monitors:   %s\n' "${monitors:-unknown}"
printf 'Distro:     %s\n' "${distro:-unknown}"
printf 'Config:     %s\n' "$config_info${config_state:+, $config_state}"
