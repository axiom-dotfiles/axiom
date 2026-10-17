#!/usr/bin/env bash
# The loop to run after changing anything: checks what changed against HEAD
# (plus new files), the way CI will, and shows what the live shell logged.
#
#   1. formats changed QML with Qt 6's qmlformat, writing in place so the
#      file keeps its inode and the running shell still reloads it
#   2. check_structure, gen_docs (rewrites docs/dev/config + generated),
#      check_docs, qmllint, the unit tests the change touches (QML, and
#      the test_scripts.py classes of a changed script), shellcheck, i18n
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
# shellcheck source=../lib/qt_paths.sh
source "$root/scripts/lib/qt_paths.sh"

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

qml=() tests=() shells=() script_tests=() schema=0
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
  # tests/scripts/test_scripts.py's classes for each script (the whole
  # file takes ~15 s); a new script with tests gets a line here
  case "$f" in
  scripts/theme_*.sh | scripts/lib/theme_env.sh | scripts/templates/* | config/themes/* | config/json/theme-defaults.json)
    script_tests+=(Themes TerminalPalette ThemeIntegrations)
    ;;
  scripts/integration_hookup.py) script_tests+=(HookupScript) ;;
  scripts/self_update.sh) script_tests+=(SelfUpdate) ;;
  scripts/claim_hyprland.sh) script_tests+=(ClaimHyprland) ;;
  scripts/claim_sway.sh) script_tests+=(ClaimSway) ;;
  scripts/merge_sway_binds.py | components/methods/BindActions.qml) script_tests+=(MergeSwayBinds MergeNiriBinds) ;;
  scripts/bind_merge_common.py) script_tests+=(MergeSwayBinds MergeHyprBinds MergeNiriBinds) ;;
  scripts/claim_niri.sh) script_tests+=(ClaimNiri) ;;
  scripts/merge_niri_binds.py) script_tests+=(MergeNiriBinds) ;;
  scripts/niri_kdl.py | scripts/niri_config.py) script_tests+=(NiriConfig MergeNiriBinds) ;;
  scripts/merge_hypr_binds.py | scripts/hypr_binds.lua) script_tests+=(MergeHyprBinds ClaimHyprland) ;;
  scripts/generate_theme.py) script_tests+=(GenerateTheme) ;;
  scripts/calendar_sync.py | scripts/setup_venv.sh | scripts/requirements.txt) script_tests+=(CalendarSync GenerateTheme) ;;
  scripts/greeter/*) script_tests+=(GreeterInstall) ;;
  scripts/pick_path.py) script_tests+=(PickPath) ;;
  scripts/sway_config_text.py) script_tests+=(SwayConfigText) ;;
  scripts/dev/known_issues.py) script_tests+=(KnownIssues) ;;
  scripts/migrate_xdg.sh) script_tests+=(MigrateXdg) ;;
  tests/scripts/test_scripts.py) script_tests+=(all) ;;
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
if [[ ${#script_tests[@]} -gt 0 ]]; then
  if printf '%s\n' "${script_tests[@]}" | grep -qx all; then
    step "script tests (all)" python3 tests/scripts/test_scripts.py
  else
    mapfile -t script_tests < <(printf '%s\n' "${script_tests[@]}" | sort -u)
    step "script tests (${script_tests[*]})" python3 tests/scripts/test_scripts.py "${script_tests[@]}"
  fi
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
