#!/usr/bin/env bash
# Run the QML unit tests (tests/tst_*.qml) with qmltestrunner, outside qs.
#
# The tests cover components/methods/ (pure by the layering rule), imported
# from a module tree of the shell's Quickshell-free files
# (scripts/qml_modules.py --pure). Lua the tests write to tests/.out/ is
# checked with `luac -p` afterwards, *.run.lua files are also run with
# `lua` (they stub what they call and error on a failed check), and
# *.hypr.lua files (whole Hyprland configs) are read by Hyprland itself
# (`Hyprland --verify-config`) where it's installed.
#
#   scripts/run_tests.sh             every test
#   scripts/run_tests.sh NAME...     only tests/tst_NAME.qml
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=lib/qt_paths.sh
source "$root/scripts/lib/qt_paths.sh"
tree="$(mktemp -d)"
trap 'rm -rf "$tree"' EXIT

python3 "$root/scripts/qml_modules.py" --pure "$tree"
rm -rf "$root/tests/.out"
mkdir -p "$root/tests/.out"

# qmltestrunner takes one -input (a later one replaces it), so named tests
# run one at a time
inputs=()
if [ $# -eq 0 ]; then
  inputs=("$root/tests")
else
  for name in "$@"; do inputs+=("$root/tests/tst_$name.qml"); done
fi

status=0
for input in "${inputs[@]}"; do
  QML_XHR_ALLOW_FILE_READ=1 QML_XHR_ALLOW_FILE_WRITE=1 QT_QPA_PLATFORM=offscreen \
    "$qt_bin/qmltestrunner" -import "$tree" -input "$input" || status=$?
done

shopt -s nullglob
for lua in "$root"/tests/.out/*.lua; do
  if ! luac -p "$lua"; then
    echo "error: ${lua#"$root"/} is not valid Lua"
    status=1
  elif [[ "$lua" == *.run.lua ]] && ! lua "$lua"; then
    echo "error: ${lua#"$root"/} failed"
    status=1
  elif [[ "$lua" == *.hypr.lua ]] && command -v Hyprland >/dev/null; then
    if ! verified=$(cd "$tree" && timeout 30 Hyprland --verify-config -c "$lua" 2>&1) ||
      ! grep -q '^config ok' <<<"$verified"; then
      grep -v DEBUG <<<"$verified" | tail -n 20
      echo "error: Hyprland refuses ${lua#"$root"/}"
      status=1
    fi
  fi
done
exit "$status"
