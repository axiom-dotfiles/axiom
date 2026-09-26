#!/usr/bin/env python3
"""Lay the shell out as a QML module tree that plain Qt tools can import.

qs resolves `import qs.…` itself, from the shell's directories, so qmllint
and qmltestrunner can't see those modules on their own. This builds what qs
builds in its runtime VFS: `<out>/qs/<dir>/` per directory, each .qml file
copied in (qmllint follows symlinks back to the repo and then sees two
types per file), and a `qmldir` listing the directory's types (singletons
declared as such, which qs's own VFS leaves out). Point a tool at it with
`-I <out>`.

  scripts/qml_modules.py OUT         build the tree in OUT (emptied first)
  scripts/qml_modules.py --pure OUT  only files that don't import Quickshell
"""
import re
import shutil
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
QML_DIRS = ["components", "shell", "services", "config"]

SINGLETON = re.compile(r"^\s*pragma\s+Singleton\b", re.M)


def qml_files():
    """Every QML file the shell loads: shell.qml and the module directories."""
    files = [ROOT / "shell.qml"]
    for d in QML_DIRS:
        files.extend(sorted((ROOT / d).rglob("*.qml")))
    return files


QUICKSHELL_IMPORT = re.compile(r"^import Quickshell\b", re.M)


def pure(path):
    """Imports nothing from Quickshell, whose modules only exist inside qs."""
    return not QUICKSHELL_IMPORT.search(path.read_text())


def build_tree(out, only=None):
    """Build the module tree in `out` (emptied first); returns `out`.

    `only` (a path predicate) keeps just the files it accepts, e.g. `pure`
    for qmltestrunner, which can't load Quickshell's modules."""
    out = Path(out)
    if out.exists():
        shutil.rmtree(out)
    by_dir = {}
    for f in qml_files():
        if only and not only(f):
            continue
        by_dir.setdefault(f.parent.relative_to(ROOT), []).append(f)
    for rel_dir, files in sorted(by_dir.items()):
        target = out / "qs" / rel_dir
        target.mkdir(parents=True, exist_ok=True)
        module = ".".join(("qs",) + rel_dir.parts)
        lines = [f"module {module}"]
        for f in sorted(files):
            shutil.copy2(f, target / f.name)
            kind = "singleton " if SINGLETON.search(f.read_text()) else ""
            lines.append(f"{kind}{f.stem} 1.0 {f.name}")
        (target / "qmldir").write_text("\n".join(lines) + "\n")
    return out


def main():
    args = sys.argv[1:]
    only = pure if args[:1] == ["--pure"] else None
    args = args[1:] if only else args
    if len(args) != 1:
        sys.exit(__doc__.strip())
    build_tree(args[0], only)


if __name__ == "__main__":
    main()
