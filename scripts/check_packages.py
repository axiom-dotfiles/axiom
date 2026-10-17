#!/usr/bin/env python3
"""Check that the two package lists agree.

install.sh and components/methods/Packages.qml (the onboarder's install
hints) each say what installs axiom's dependencies; this fails when they
drift:
- every key in install.sh's PACKAGES names the same Arch and Fedora package
  as Packages.packages (a COPR as Packages' `repo`, "download" as its
  `{ file, to }` with install.sh's ICON_FONT_URL and ICON_FONT_FILE, "-" and
  "n/a" as null)
- every key install.sh's REQUIRED and FEATURES use is in PACKAGES

Prints `error    <file>: <message>` per problem, as check_structure does.

  scripts/check_packages.py
"""
import json
import re
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
INSTALL = ROOT / "install.sh"
PACKAGES_QML = ROOT / "components/methods/Packages.qml"
DISTROS = ("arch", "fedora")
COMPOSITORS = ("hyprland", "sway", "niri")

errors = []


def error(path, message):
    errors.append(f"error    {path.relative_to(ROOT)}: {message}")


def bash_array(text, name):
    """A bash array's items, as bash reads its definition"""
    match = re.search(rf"^{name}=\((?:[^\n]*\)$|.*?^\)$)", text, re.S | re.M)
    if not match:
        return None
    done = subprocess.run(["bash", "-c", f'{match.group(0)}\nprintf "%s\\0" "${{{name}[@]}}"'], capture_output=True, text=True)
    return [item for item in done.stdout.split("\0") if item] if done.returncode == 0 else None


def bash_value(text, name):
    match = re.search(rf"^{name}=(.*)$", text, re.M)
    return match.group(1).strip().strip("\"'") if match else None


def qml_packages():
    """Packages.packages as data: its root.<name> strings filled in"""
    text = PACKAGES_QML.read_text()
    strings = dict(re.findall(r'readonly property string (\w+): "([^"]*)"', text))
    start = text.index("readonly property var packages: (") + len("readonly property var packages: (")
    depth = 0
    for i in range(start, len(text)):
        depth += {"{": 1, "}": -1}.get(text[i], 0)
        if depth == 0:
            break
    body = re.sub(r"root\.(\w+)", lambda m: json.dumps(strings[m.group(1)]), text[start:i + 1])
    return json.loads(body)


def same(cell, entry, font):
    """Whether an install.sh cell says what a Packages entry does"""
    if cell in ("-", "n/a"):
        return entry is None
    if cell == "download":
        return isinstance(entry, dict) and entry.get("file") == font[0] and entry.get("to") == font[1]
    name = cell.split(":")[-1]
    repo = cell.split(":")[0] if "/" in cell and ":" in cell else None
    if isinstance(entry, str):
        return repo is None and entry == name
    return isinstance(entry, dict) and entry.get("name") == name and entry.get("repo") == repo


def main():
    text = INSTALL.read_text()
    rows = bash_array(text, "PACKAGES")
    required = bash_array(text, "REQUIRED")
    features = bash_array(text, "FEATURES")
    if rows is None or required is None or features is None:
        error(INSTALL, "PACKAGES, REQUIRED or FEATURES not found")
        return
    font = (bash_value(text, "ICON_FONT_URL"), (bash_value(text, "ICON_FONT_FILE") or "").replace("$HOME", "~"))
    table = {}
    for row in rows:
        cells = row.split("|")
        if len(cells) != 1 + len(DISTROS):
            error(INSTALL, f"PACKAGES row {row!r} isn't key|arch|fedora")
            continue
        table[cells[0]] = dict(zip(DISTROS, cells[1:]))

    packages = qml_packages()
    for key, cells in table.items():
        if key not in packages:
            error(PACKAGES_QML, f"no key {key!r} (install.sh installs it)")
            continue
        for distro in DISTROS:
            if not same(cells[distro], packages[key].get(distro), font):
                error(INSTALL, f"{key} on {distro} is {cells[distro]!r}, Packages.qml says {packages[key].get(distro)!r}")

    for feature in features:
        name, keys, _ = (feature.split("|") + ["", ""])[:3]
        for key in keys.split():
            if key not in table:
                error(INSTALL, f"feature {name!r} uses {key!r}, which isn't in PACKAGES")
    for key in required + list(COMPOSITORS):
        if key not in table:
            error(INSTALL, f"{key!r} isn't in PACKAGES")


main()
for line in errors:
    print(line)
print(f"packages: {len(errors)} errors" if errors else "packages ok")
sys.exit(1 if errors else 0)
