#!/usr/bin/env bash
# Every tracked .qml file is as qmlformat (Qt 6, .qmlformat.ini) writes it.
# Qt 6's qmlformat, found by scripts/lib/qt_paths.sh.
#
#   scripts/check_qmlformat.sh         list unformatted files (exit 1)
#   scripts/check_qmlformat.sh --fix   format them in place (keeping the
#                                      inode, so the running shell reloads)
set -uo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=lib/qt_paths.sh
source "$root/scripts/lib/qt_paths.sh"
qmlformat="$qt_bin/qmlformat"
cd "$root" || exit 1

# One file: prints what's wrong in one write (the files run in parallel)
check_one() {
  local file="$1" formatted
  if ! formatted=$("$qmlformat" "$file"); then
    echo "error: qmlformat can't parse $file"
    return 1
  elif [[ "$formatted" != "$(<"$file")" ]]; then
    if [[ "$fix" == 1 ]]; then
      printf '%s\n' "$formatted" >"$file" && echo "formatted $file"
    else
      printf '%s\n%s\n' "error: $file is not formatted" \
        "$(diff -u "$file" <(printf '%s\n' "$formatted") | head -n 20)"
      return 1
    fi
  fi
}
fix=0
[[ "${1:-}" == "--fix" ]] && fix=1
export -f check_one
export qmlformat fix

bad=0
# A file deleted but not staged yet is still listed: skipped
git ls-files -z '*.qml' |
  xargs -0 -n 8 -P "$(nproc)" bash -c 'status=0; for f; do [[ -e "$f" ]] || continue; check_one "$f" || status=1; done; exit $status' _ ||
  bad=1

if [[ $bad -ne 0 ]]; then
  echo "run scripts/check_qmlformat.sh --fix"
  exit 1
fi
echo "qmlformat ok"
