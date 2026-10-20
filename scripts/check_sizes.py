#!/usr/bin/env python3
"""Keep sizes outside the bars on the Interface scale and Density.

Text grows with `Widget.scale` (Appearance.fontSize), and so do the
`Widget` sizes (height, padding, spacing, iconButton, smallHeight,
smallPadding, `Widget.px(n)`). A size written as a bare number stays the
same at every scale, so next to the text around it it comes out cramped at
150 % and loose at 75 %. This fails on:

  - a size property (one named …width, …height, …size, …spacing,
    …margin(s), …padding, …radius, …length or …thickness: width,
    Layout.preferredHeight, anchors.leftMargin, textSize), or a
    `property int|real` of that name, set to a number of 3 or more
  - a font size offset, `Appearance.fontSize + n` (or fontSizeLarge):
    the offset stays the same at every scale; use
    `Appearance.fontSizeBy(n)`

Left alone: components/bar/ (each bar sizes its own widgets),
components/methods/ (pure helpers: sizes are handed in), hairlines
(0–2 px, `border.width`), and a line marked `// fixed px: <reason>` (a
size measured against the screen or a measuring font, never the UI).

  scripts/check_sizes.py            errors (exit 1)
"""
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
DIRS = ["components", "shell"]
SKIP = ["components/bar/", "components/methods/"]

SIZE_WORD = r"(?:[wW]idth|[hH]eight|[sS]ize|[sS]pacing|[mM]argins?|[pP]adding|[rR]adius|[lL]ength|[tT]hickness)"
# width, Layout.preferredHeight, anchors.leftMargin, textSize, troughHeight, …
SIZE_NAME = r"(?:[\w.]*" + SIZE_WORD + r")"
NUMBER = r"(\d+(?:\.\d+)?)"
# `name: 12` (an assignment) or `property int name: 12` (a default)
ASSIGN = re.compile(r"^\s*(?:readonly\s+)?(?:property\s+(?:int|real)\s+)?(" + SIZE_NAME + r")\s*:\s*" + NUMBER + r"\s*(?://.*)?$")
MARK = "// fixed px:"
# `Appearance.fontSize - 2`, not `Appearance.fontSize * 2`
FONT_OFFSET = re.compile(r"Appearance\.(fontSize(?:Large)?)\s*[-+]\s*\d")


def find_literals(text):
    """(line number, property, value) for each literal size in QML text."""
    found = []
    for n, line in enumerate(text.split("\n"), 1):
        if MARK in line or "border.width" in line:
            continue
        m = ASSIGN.match(line)
        if m and float(m.group(2)) >= 3:
            found.append((n, m.group(1), m.group(2)))
        offset = FONT_OFFSET.search(line)
        if offset:
            found.append((n, offset.group(1), offset.group(0)))
    return found


def main():
    errors = []
    for d in DIRS:
        for path in sorted((ROOT / d).rglob("*.qml")):
            rel = path.relative_to(ROOT).as_posix()
            if any(rel.startswith(s) for s in SKIP):
                continue
            for n, name, value in find_literals(path.read_text()):
                errors.append(f"{rel}:{n}: {name}: {value}")
    for e in errors:
        print(e)
    if errors:
        print(
            f"\n{len(errors)} literal size(s): use a Widget size (height, padding, spacing, "
            "iconButton, smallHeight, smallPadding), Widget.px(n) or "
            "Appearance.fontSizeBy(n), or mark the line "
            "`// fixed px: <reason>` if it's measured against the screen"
        )
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
