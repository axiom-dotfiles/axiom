#!/bin/sh
#
# Description: greetd's greeter command, as greeter_install.sh points
#              default_session at it (run as greetd's user, from the
#              installed copy):
#                greeter-session.sh         axiom's greeter in a Hyprland of
#                                           its own (hyprland.lua beside
#                                           this); if Hyprland can't start,
#                                           greetd's text greeter, agreety,
#                                           so a login is always possible
#                greeter-session.sh shell   (from that Hyprland) the greeter
#                                           itself; if it fails without
#                                           starting a session, once more on
#                                           its fallback config only; then
#                                           Hyprland exits, and greetd starts
#                                           the session or the greeter again
#                                           (agreety instead, when the second
#                                           try failed too)

here=$(dirname "$(readlink -f "$0")")
copy=$(cd "$here/../.." && pwd)
# Left by `shell` when the greeter failed twice: in greetd's user's own
# folders (its runtime dir, else the greeter's state folder), never a
# shared one another user could plant it in
failed="${XDG_RUNTIME_DIR:-/var/lib/axiom-greeter/state}/axiom-greeter-failed"
# greetd's user has / for a home, which it can't write: caches (Hyprland's,
# Quickshell's QML cache) go to the greeter's own state folder
export XDG_CACHE_HOME="${XDG_CACHE_HOME:-/var/lib/axiom-greeter/state/cache}"

case "${1:-}" in
shell)
  export AXIOM_GREETER=1
  if ! qs -p "$copy/greeter.qml"; then
    echo "axiom greeter: failed, trying its fallback config" >&2
    AXIOM_GREETER_SAFE=1 qs -p "$copy/greeter.qml" || : >"$failed"
  fi
  hyprctl dispatch 'hl.dsp.exit()' >/dev/null
  ;;
*)
  rm -f "$failed"
  if start-hyprland -- --config "$here/hyprland.lua" && [ ! -e "$failed" ]; then
    exit 0
  fi
  rm -f "$failed"
  echo "axiom greeter: didn't start, falling back to agreety" >&2
  # greetd runs the command through sh in the new session, where SHELL
  # is the login shell of whoever logged in (not greetd's user's)
  # shellcheck disable=SC2016
  exec agreety --cmd '${SHELL:-/bin/sh}'
  ;;
esac
