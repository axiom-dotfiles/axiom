#!/usr/bin/env bash
# Screenshot a surface of the live shell for a visual check, then close it.
# Prints the PNG's path (read it to look). Never moves the cursor.
#
#   scripts/dev/shot.sh page <ViewType>                 an overlay page
#   scripts/dev/shot.sh launcher [search text]          the launcher
#   scripts/dev/shot.sh ipc <target> <open> [close]     anything with an IPC
#                                                       open/toggle function
#   scripts/dev/shot.sh screen                          just the screen
#
# Options (before the mode): -m MONITOR (default: the focused one),
# -o FILE (default: a temp file), -w SECONDS to wait before the shot (1).
# `show` is a qs keyword (it lists functions), so open with toggle instead.
set -euo pipefail

monitor="" out="" wait=1
while getopts "m:o:w:" opt; do
  case "$opt" in
  m) monitor="$OPTARG" ;;
  o) out="$OPTARG" ;;
  w) wait="$OPTARG" ;;
  *) sed -n '2,16p' "$0" >&2; exit 2 ;;
  esac
done
shift $((OPTIND - 1))
mode="${1:-}"
[[ -n "$mode" ]] || { sed -n '2,16p' "$0" >&2; exit 2; }
shift

ipc() { qs -c axiom ipc call "$@" >/dev/null; }
[[ -n "$monitor" ]] || monitor="$(hyprctl monitors -j | jq -r '.[] | select(.focused) | .name')"
[[ -n "$out" ]] || out="$(mktemp --suffix=.png "${TMPDIR:-/tmp}/axiom-shot-XXXXXX")"

close=()
case "$mode" in
page)
  ipc overlay page "${1:?ViewType}"
  close=(overlay close)
  ;;
launcher)
  if [[ $# -gt 0 ]]; then ipc appLauncher search "$*"; else ipc appLauncher open; fi
  close=(appLauncher close)
  ;;
ipc)
  target="${1:?target}" open="${2:?open function}"
  ipc "$target" "$open"
  close=("$target" "${3:-$open}")
  ;;
screen) ;;
*)
  echo "unknown mode: $mode" >&2
  exit 2
  ;;
esac

sleep "$wait"
grim -o "$monitor" "$out"
[[ ${#close[@]} -gt 0 ]] && ipc "${close[@]}"
echo "$out"
