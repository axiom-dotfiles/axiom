#!/usr/bin/env bash
# Every tracked .qml file is as qmlformat (Qt 6, .qmlformat.ini) writes it.
# The qmlformat on PATH may be Qt 5's, which fails silently on
# `pragma ComponentBehavior`, so this uses Qt 6's by path.
#
#   scripts/check_qmlformat.sh         list unformatted files (exit 1)
#   scripts/check_qmlformat.sh --fix   format them in place
set -uo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
qmlformat="${QT_BIN:-/usr/lib/qt6/bin}/qmlformat"
cd "$root" || exit 1

bad=0
while IFS= read -r -d '' file; do
  if ! formatted=$("$qmlformat" "$file"); then
    echo "error: qmlformat can't parse $file"
    bad=1
  elif [[ "$formatted" != "$(<"$file")" ]]; then
    if [[ "${1:-}" == "--fix" ]]; then
      "$qmlformat" -i "$file" && echo "formatted $file"
    else
      echo "error: $file is not formatted"
      diff -u "$file" <(printf '%s\n' "$formatted") | head -n 20
      bad=1
    fi
  fi
done < <(git ls-files -z '*.qml')

if [[ $bad -ne 0 ]]; then
  echo "run scripts/check_qmlformat.sh --fix"
  exit 1
fi
echo "qmlformat ok"
