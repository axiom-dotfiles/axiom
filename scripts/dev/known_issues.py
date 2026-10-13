#!/usr/bin/env python3
"""Mark log lines (stdin) that an open docs/dev/issues.md entry already covers.

A line is known when it names a QML file (`@path/File.qml[line:col]`) that the
entry's **Where** cites and contains a backticked quote from its **What** (at
least 12 characters: quote the warning's message there). Such a line gets
`  (known: issues.md › <title>)` appended; everything else passes through as is.

  scripts/log.sh | scripts/dev/known_issues.py
"""
import re
import sys
from pathlib import Path

ISSUES = Path(__file__).resolve().parent.parent.parent / "docs/dev/issues.md"
LOG_FILE = re.compile(r"@([\w./-]+\.qml)\[")
TICKED = re.compile(r"`([^`]+)`")


def entries():
    """[(title, cited paths, quotes)] for each open entry"""
    text = ISSUES.read_text() if ISSUES.exists() else ""
    out = []
    for block in re.split(r"^### ", text, flags=re.M)[1:]:
        title = block.splitlines()[0].strip().replace("`", "")
        where = re.search(r"^- \*\*Where:\*\* (.*)$", block, re.M)
        what = re.search(r"^- \*\*What:\*\* (.*)$", block, re.M)
        if not where or not what:
            continue
        paths = {p for p in TICKED.findall(where.group(1)) if p.endswith(".qml")}
        quotes = [q for q in TICKED.findall(what.group(1)) if len(q) >= 12]
        if paths and quotes:
            out.append((title, paths, quotes))
    return out


def main():
    known = entries()
    for line in sys.stdin:
        line = line.rstrip("\n")
        match = LOG_FILE.search(line)
        if match:
            for title, paths, quotes in known:
                if match.group(1) in paths and any(q in line for q in quotes):
                    line += f"  (known: issues.md › {title})"
                    break
        print(line)


if __name__ == "__main__":
    main()
