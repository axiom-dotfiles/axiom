#!/usr/bin/env python3
"""Run qmllint over the shell, failing only on warnings not in the baseline.

qmllint can't resolve `import qs.…` by itself, so this lints a copy of the
shell laid out as QML modules (scripts/qml_modules.py). Many of its warnings
are gaps in Quickshell's type info rather than bugs, so the known ones are
kept in scripts/qmllint-baseline.json, per file, as "category: message"
with a count (no line numbers, so unrelated edits don't churn it). A new
warning, or one more of a known kind in the same file, fails the check.

  scripts/check_qmllint.py                    lint (exit 1 on new warnings)
  scripts/check_qmllint.py --update-baseline  accept the current warnings
"""
import collections
import json
import subprocess
import sys
import tempfile
from pathlib import Path

from qml_modules import ROOT, build_tree

QMLLINT = "/usr/lib/qt6/bin/qmllint"
QT_QML = "/usr/lib/qt6/qml"
BASELINE = ROOT / "scripts" / "qmllint-baseline.json"
# Quickshell's type info can't express these, so every file would hit them:
# PanelWindow reads as uncreatable, and Process.exited's QProcess enum is
# not exported
DISABLED = ["uncreatable-type", "signal-handler-parameters"]


def lint():
    """{repo-relative file: Counter("category: message")}, and the raw lines."""
    with tempfile.TemporaryDirectory() as tmp:
        tree = build_tree(Path(tmp) / "tree")
        files = sorted(str(p) for p in (tree / "qs").rglob("*.qml"))
        report = Path(tmp) / "report.json"
        args = [QMLLINT, "--json", str(report), "-I", str(tree), "-I", QT_QML]
        for category in DISABLED:
            args += [f"--{category}", "disable"]
        subprocess.run(args + files, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        data = json.loads(report.read_text())
        prefix = str(tree / "qs") + "/"
    found, lines = {}, collections.defaultdict(list)
    for entry in data["files"]:
        name = entry["filename"].removeprefix(prefix)
        for w in entry["warnings"]:
            key = f"{w.get('id', 'unknown')}: {w['message']}"
            found.setdefault(name, collections.Counter())[key] += 1
            lines[(name, key)].append(w.get("line"))
    return found, lines


def main():
    found, lines = lint()
    if "--update-baseline" in sys.argv:
        baseline = {f: dict(sorted(c.items())) for f, c in sorted(found.items())}
        BASELINE.write_text(json.dumps(baseline, indent=2) + "\n")
        print(f"baseline: {sum(sum(c.values()) for c in found.values())} warnings")
        return
    baseline = json.loads(BASELINE.read_text()) if BASELINE.exists() else {}
    new, fixed = [], 0
    for name, counts in sorted(found.items()):
        known = baseline.get(name, {})
        for key, n in sorted(counts.items()):
            if n > known.get(key, 0):
                at = ",".join(str(ln) for ln in lines[(name, key)] if ln)
                new.append(f"{name}:{at}: {key}" + (f" ({n - known.get(key, 0)} new)" if known.get(key) else ""))
    for name, known in baseline.items():
        for key, n in known.items():
            fixed += max(0, n - found.get(name, {}).get(key, 0))
    for line in new:
        print(f"error: {line}")
    if fixed:
        print(f"note: {fixed} baselined warnings are gone; run with --update-baseline to drop them")
    if new:
        print(f"{len(new)} new qmllint warnings (fix them, or --update-baseline if they're false positives)")
        sys.exit(1)
    print("qmllint ok")


if __name__ == "__main__":
    main()
