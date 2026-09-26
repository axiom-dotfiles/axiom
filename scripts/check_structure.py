#!/usr/bin/env python3
"""Guard the naming conventions the shell loads by.

Much of the shell has no lookup tables: a schema type or popout name *is*
a file name, loaded by URL at runtime. A typo, a rename or a missing import
only shows up when something tries to instantiate it. This checks, without
running anything:

  - every schema type (BarWidget → bar/widgets, OverlayView → views,
    OverlayModule → content) and every PopoutAnchor popoutName (→ content)
    has its file, and nothing is left under retired directories
  - every URL-loaded directory is imported by name somewhere (qs only makes
    sibling types visible to URL-loaded files in directories it scanned)
  - every `import qs.…` names a directory that exists
  - no file instantiates a type that two of its visible directories define
  - every `SomethingManager.` names a service that exists, and nothing
    references a near-miss of a project singleton (a typo)
and warns about files in the loaded directories that nothing registers or
uses.

  scripts/check_structure.py        errors (exit 1) and warnings
"""
import difflib
import json
import re
import sys
from pathlib import Path

from qml_modules import qml_files

ROOT = Path(__file__).resolve().parent.parent
SCHEMA = ROOT / "config" / "json" / "config.schema.json"

# (schema oneOf definition, directory its types load from, import that must
# exist somewhere so qs scans that directory)
LOADERS = [
    ("BarWidget", "components/bar/widgets", "qs.components.bar.widgets"),
    ("OverlayView", "components/views", "qs.components.views"),
    ("OverlayModule", "components/content", "qs.components.content"),
]
# Bar popouts load content/<popoutName>.qml, from the same directory as
# overlay modules (a content file can be both)
POPOUT_DIR = "components/content"
POPOUT_IMPORT = "qs.components.content"
# Directories retired by restructuring: nothing may live or be imported there
RETIRED = ["components/widgets", "components/stolen"]

errors, warnings = [], []


def rel(path):
    return path.relative_to(ROOT).as_posix()


def schema_types(schema, name):
    defs = schema["definitions"]
    types = []
    for option in defs[name]["oneOf"]:
        target = defs.get(option.get("$ref", "").split("/")[-1], option)
        const = target.get("properties", {}).get("type", {}).get("const")
        if const:
            types.append(const)
    return types


def main():
    schema = json.loads(SCHEMA.read_text())
    sources = {rel(f): f.read_text() for f in qml_files()}
    everything = "\n".join(sources.values())
    imports = set(re.findall(r"^import (qs(?:\.\w+)+)", everything, re.M))

    def used_as_type(name, besides):
        """Instantiated or referenced by name anywhere but its own file."""
        pattern = re.compile(r"\b" + re.escape(name) + r"\b")
        return any(pattern.search(text) for path, text in sources.items() if path != besides)

    # Schema types -> files, and the directories' named imports
    for definition, directory, required_import in LOADERS:
        types = schema_types(schema, definition)
        for t in types:
            if not (ROOT / directory / f"{t}.qml").exists():
                errors.append(f"{definition} type '{t}' has no {directory}/{t}.qml")
        if required_import not in imports:
            errors.append(f"nothing imports {required_import}: files loaded by URL from {directory} won't see each other's types")
        for f in sorted((ROOT / directory).glob("*.qml")):
            if directory == POPOUT_DIR:
                continue  # content: checked below, with popout names
            if f.stem not in types and not used_as_type(f.stem, rel(f)):
                warnings.append(f"{rel(f)}: not a {definition} type and not used anywhere")

    # Popout names -> content files
    names = {}
    for path, text in sources.items():
        for m in re.finditer(r'popoutName:\s*"([^"]+)"', text):
            names.setdefault(m.group(1), path)
    for name, path in sorted(names.items()):
        if not (ROOT / POPOUT_DIR / f"{name}.qml").exists():
            errors.append(f'{path}: popoutName "{name}" has no {POPOUT_DIR}/{name}.qml')
    if POPOUT_IMPORT not in imports:
        errors.append(f"nothing imports {POPOUT_IMPORT}: popout content won't see its sibling types")
    # A content file is fine if it's an overlay module type, a popout name,
    # or used by name somewhere
    module_types = set(schema_types(schema, "OverlayModule"))
    for f in sorted((ROOT / POPOUT_DIR).glob("*.qml")):
        if f.stem not in names and f.stem not in module_types and not used_as_type(f.stem, rel(f)):
            warnings.append(f"{rel(f)}: not an overlay module, no PopoutAnchor opens it, and nothing uses it")

    # Retired directories stay empty
    for d in RETIRED:
        leftovers = list((ROOT / d).rglob("*.qml")) if (ROOT / d).exists() else []
        for f in leftovers:
            errors.append(f"{rel(f)}: lives under retired {d}/")

    # qs.* imports resolve
    for path, text in sources.items():
        for m in re.finditer(r"^import (qs(?:\.\w+)+)", text, re.M):
            target = ROOT.joinpath(*m.group(1).split(".")[1:])
            if not target.is_dir():
                errors.append(f"{path}: import {m.group(1)} — no such directory")

    # Singleton references: FooManager. must be a service, and a near-miss
    # of any project singleton (AudioManger.) is a typo
    external = {"ToplevelManager"}  # Quickshell's own
    singletons = {f.stem for d in ("services", "config", "components/methods") for f in (ROOT / d).glob("*.qml")}
    services = {f.stem for f in (ROOT / "services").glob("*.qml")} | external
    for path, text in sources.items():
        # without strings and comments
        code = re.sub(r'"(?:[^"\\\n]|\\.)*"|`[^`]*`', '""', text)
        code = re.sub(r"//[^\n]*", "", code)
        for name in sorted(set(re.findall(r"(?<![\w.])([A-Z]\w+)\.", code))):
            if name in singletons or name in external:
                continue
            if name.endswith("Manager") and name not in services:
                errors.append(f"{path}: {name} is not a service")
                continue
            close = difflib.get_close_matches(name, singletons, n=1, cutoff=0.85)
            if close:
                errors.append(f"{path}: {name} — did you mean {close[0]}?")

    # A type instantiated from two directories a file can see would depend
    # on import order (bar widgets and content share some names by design)
    dir_types = {}
    for f in qml_files():
        if rel(f).startswith(("components/", "shell/")):
            dir_types.setdefault("qs." + rel(f.parent).replace("/", "."), set()).add(f.stem)
    for path, text in sources.items():
        own = "qs." + str(Path(path).parent).replace("/", ".")
        visible = [d for d in set(re.findall(r"^import (qs(?:\.\w+)+)", text, re.M)) | {own} if d in dir_types]
        code = re.sub(r'"(?:[^"\\\n]|\\.)*"', '""', re.sub(r"//[^\n]*", "", text))
        for name in sorted(set(re.findall(r"(?<![\w.])([A-Z]\w+)\s*\{", code)) - {Path(path).stem}):
            sources_of = [d for d in visible if name in dir_types[d]]
            if len(sources_of) > 1:
                errors.append(f"{path}: {name} is defined in {' and '.join(sorted(sources_of))}; import only one")

    for e in errors:
        print(f"error    {e}")
    for w in warnings:
        print(f"warning  {w}")
    if not errors and not warnings:
        print("structure ok")
    return 1 if errors else 0


if __name__ == "__main__":
    sys.exit(main())
