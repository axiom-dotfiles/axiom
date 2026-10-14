#!/usr/bin/env bash
# The loop to run after changing anything: checks what changed against HEAD
# (plus new files), the way CI will, and shows what the live shell logged.
#
#   1. formats changed QML with Qt 6's qmlformat, writing in place so the
#      file keeps its inode and the running shell still reloads it
#   2. check_structure, gen_docs (rewrites docs/dev/config + generated),
#      check_docs, qmllint, the unit tests the change touches, shellcheck, i18n
#   3. the shell's log since its last reload, lines issues.md already
#      covers marked (known: …)
#   4. warnings: the docs describing the changed files (check_doc_drift.py),
#      and a missing pre-commit hook
#
#   scripts/dev/verify.sh             what changed since HEAD
#   scripts/dev/verify.sh --all       every check on everything (check_all.sh)
#   --no-docs (with either)           skip rebuilding the generated docs (the
#                                     pre-commit hook rebuilds them anyway)
set -uo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$root" || exit 1
qt_bin="${QT_BIN:-/usr/lib/qt6/bin}"

all=0 docs=1
for arg in "$@"; do
  case "$arg" in
  --all) all=1 ;;
  --no-docs) docs=0 ;;
  *)
    sed -n '2,19p' "$0" >&2
    exit 2
    ;;
  esac
done
if [[ $all -eq 1 ]]; then
  if [[ $docs -eq 1 ]]; then exec scripts/check_all.sh; else exec scripts/check_all.sh --no-docs; fi
fi

mapfile -t changed < <({
  git diff --name-only HEAD
  git ls-files -o --exclude-standard
} | sort -u | while read -r f; do [[ -f "$f" ]] && echo "$f"; done)

if [[ ${#changed[@]} -eq 0 ]]; then
  echo "nothing changed since HEAD"
  exit 0
fi

failed=()
step() {
  local name="$1"
  shift
  echo "── $name"
  "$@" || failed+=("$name")
}

qml=() tests=() shells=() schema=0
for f in "${changed[@]}"; do
  case "$f" in
  *.qml) qml+=("$f") ;;
  *.sh) shells+=("$f") ;;
  esac
  case "$f" in
  config/json/config.schema.json | components/methods/ConfigMigration.qml) schema=1 ;;
  esac
  case "$f" in
  components/methods/*.qml)
    name="$(basename "$f" .qml)"
    [[ -f "tests/tst_$name.qml" ]] && tests+=("$name")
    ;;
  tests/tst_*.qml)
    name="$(basename "$f" .qml)"
    tests+=("${name#tst_}")
    ;;
  esac
done
[[ $schema -eq 1 ]] && tests+=(Config ConfigExamples)

reloads_before=$(scripts/log.sh --all 2>/dev/null | grep -c "Reloading configuration" || true)

# 1. Format in place (cat > keeps the inode; -i would replace the file)
if [[ ${#qml[@]} -gt 0 ]]; then
  echo "── qmlformat (${#qml[@]} changed QML files)"
  formatted=0
  for f in "${qml[@]}"; do
    out="$("$qt_bin/qmlformat" "$f")" || {
      failed+=("qmlformat $f")
      continue
    }
    if [[ "$out" != "$(cat "$f")" ]]; then
      printf '%s\n' "$out" >"$f"
      echo "formatted $f"
      formatted=1
    fi
  done
  [[ $formatted -eq 0 ]] && echo "already formatted"
fi

# 2. Checks
step "structure" python3 scripts/check_structure.py
[[ $docs -eq 1 ]] && step "generated docs" python3 scripts/gen_docs.py
if printf '%s\n' "${changed[@]}" | grep -qE '\.(md|qml)$'; then
  step "doc citations" python3 scripts/check_docs.py
fi
if [[ ${#qml[@]} -gt 0 ]]; then
  step "qmllint" python3 scripts/check_qmllint.py
fi
if [[ ${#tests[@]} -gt 0 ]]; then
  mapfile -t tests < <(printf '%s\n' "${tests[@]}" | sort -u)
  step "unit tests (${tests[*]})" bash -c 'scripts/run_tests.sh "$@" 2>&1 | grep -E "^(FAIL|Totals|XPASS)|error" ; exit "${PIPESTATUS[0]}"' _ "${tests[@]}"
fi
if printf '%s\n' "${changed[@]}" | grep -qE '^(\.claude/hooks/|tests/scripts/test_guard\.py)'; then
  step "guard tests" python3 tests/scripts/test_guard.py
fi
if [[ ${#shells[@]} -gt 0 ]]; then
  step "shellcheck" shellcheck -x -S warning "${shells[@]}"
fi
if [[ ${#qml[@]} -gt 0 || $schema -eq 1 ]]; then
  echo "── translations (warnings only)"
  python3 scripts/check_i18n.py 2>&1 | tail -n 15 || true
fi

# 3. The live shell: wait briefly for the reload a save (or the formatting)
# triggered, then show what it logged
if [[ ${#qml[@]} -gt 0 || $schema -eq 1 ]] && command -v qs >/dev/null; then
  echo "── shell log since the last reload"
  for _ in 1 2 3 4 5 6; do
    now=$(scripts/log.sh --all 2>/dev/null | grep -c "Reloading configuration" || true)
    [[ $now -gt $reloads_before ]] && break
    sleep 0.5
  done
  sleep 1
  scripts/log.sh | scripts/dev/known_issues.py || true
  echo "(no new reload since this script started is normal when the shell already reloaded on save;"
  echo " if the log looks stale, see docs/dev/testing.md › Reloads and logs)"
fi

# 4. Warnings, never failures
echo "── docs"
python3 scripts/check_doc_drift.py --changed "${changed[@]}"
if [[ "$(git config core.hooksPath)" != ".githooks" ]]; then
  echo "warning: the pre-commit hook isn't set up, so commits can carry stale generated docs:"
  echo "  git config core.hooksPath .githooks"
fi

if [[ ${#failed[@]} -gt 0 ]]; then
  echo "failed: ${failed[*]}"
  exit 1
fi
echo "verify ok"
