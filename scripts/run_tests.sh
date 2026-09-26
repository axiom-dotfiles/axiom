#!/usr/bin/env bash
# Run the QML unit tests (tests/tst_*.qml) with qmltestrunner, outside qs.
#
# The tests cover components/methods/ (pure by the layering rule), imported
# from a module tree of the shell's Quickshell-free files
# (scripts/qml_modules.py --pure). Lua the tests write to tests/.out/ is
# checked with `luac -p` afterwards.
#
#   scripts/run_tests.sh             every test
#   scripts/run_tests.sh NAME...     only tests/tst_NAME.qml
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
qt_bin="${QT_BIN:-/usr/lib/qt6/bin}"
tree="$(mktemp -d)"
trap 'rm -rf "$tree"' EXIT

python3 "$root/scripts/qml_modules.py" --pure "$tree"
rm -rf "$root/tests/.out"
mkdir -p "$root/tests/.out"

inputs=()
if [ $# -eq 0 ]; then
  inputs=(-input "$root/tests")
else
  for name in "$@"; do inputs+=(-input "$root/tests/tst_$name.qml"); done
fi

status=0
QML_XHR_ALLOW_FILE_READ=1 QML_XHR_ALLOW_FILE_WRITE=1 QT_QPA_PLATFORM=offscreen \
  "$qt_bin/qmltestrunner" -import "$tree" "${inputs[@]}" || status=$?

shopt -s nullglob
for lua in "$root"/tests/.out/*.lua; do
  if ! luac -p "$lua"; then
    echo "error: ${lua#"$root"/} is not valid Lua"
    status=1
  fi
done
exit "$status"
