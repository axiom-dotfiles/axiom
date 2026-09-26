#!/usr/bin/env bash
# Every check CI runs (.github/workflows/checks.yml), in the same order.
# Needs Qt 6's tools, shellcheck, luac and jq; the script smoke tests set up
# the python venv on their first run.
#
#   scripts/check_all.sh
set -uo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$root" || exit 1

failed=()
step() {
  local name="$1"
  shift
  echo "── $name"
  "$@" || failed+=("$name")
}

step "structure" python3 scripts/check_structure.py
step "qmlformat" scripts/check_qmlformat.sh
step "qmllint" python3 scripts/check_qmllint.py
step "unit tests" scripts/run_tests.sh
step "shellcheck" shellcheck -x -S warning install.sh scripts/*.sh scripts/lib/*.sh
step "script tests" python3 tests/scripts/test_scripts.py
echo "── translations (warnings only)"
python3 scripts/check_i18n.py || true

if [[ ${#failed[@]} -gt 0 ]]; then
  echo "failed: ${failed[*]}"
  exit 1
fi
echo "all checks passed"
