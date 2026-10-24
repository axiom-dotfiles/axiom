#!/usr/bin/env bash
# Every check CI runs (.github/workflows/checks.yml), in the same order
# (the generated docs are rebuilt here, only checked in CI).
# Needs Qt 6's tools, go, shellcheck, luac and jq; the theme and calendar script
# tests also want python's numpy, Pillow and icalendar (skipped without).
#
#   scripts/check_all.sh             everything
#   scripts/check_all.sh --no-docs   skip rebuilding the generated docs (the
#                                    pre-commit hook rebuilds them anyway)
set -uo pipefail

docs=1
[[ "${1:-}" == "--no-docs" ]] && docs=0

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$root" || exit 1

failed=()
step() {
  local name="$1"
  shift
  echo "── $name"
  "$@" || failed+=("$name")
}

# The generated files the checks read (the schema, the shared fixtures)
step "generated files" scripts/generate.sh --fixtures
step "structure" python3 scripts/check_structure.py
step "sizes" python3 scripts/check_sizes.py
# Rebuilt rather than checked: locally they follow your edits (the pre-commit
# hook commits them); CI runs `gen_docs.py --check` to catch a skipped hook
[[ $docs -eq 1 ]] && step "generated docs" python3 scripts/gen_docs.py
step "docs" python3 scripts/check_docs.py
step "package lists" python3 scripts/check_packages.py
step "qmlformat" scripts/check_qmlformat.sh
step "qmllint" python3 scripts/check_qmllint.py
step "shared fixtures" python3 scripts/dev/fixtures.py check
step "unit tests" scripts/run_tests.sh
step "go" scripts/check_go.sh
step "shellcheck" shellcheck -x -S warning install.sh scripts/*.sh scripts/lib/*.sh scripts/greeter/*.sh scripts/dev/*.sh .githooks/pre-commit
step "script tests" python3 tests/scripts/test_scripts.py
step "guard tests" python3 tests/scripts/test_guard.py
echo "── translations (warnings only)"
python3 scripts/check_i18n.py || true

if [[ ${#failed[@]} -gt 0 ]]; then
  echo "failed: ${failed[*]}"
  exit 1
fi
echo "all checks passed"
