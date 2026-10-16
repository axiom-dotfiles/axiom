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
  - every file starts with `pragma ComponentBehavior: Bound` (or Singleton)
  - no file instantiates a type that two of its visible directories define
  - every `SomethingManager.` names a service that exists, and nothing
    references a near-miss of a project singleton (a typo)
  - no reader falls back with `??` on its section (`_c.key ?? x`): every
    default is filled at load, so the fallback is dead and hides a missing
    schema default
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

    # Every library type joins one of the root's `x-libraryGroups` (the
    # editors' libraries group by them); required modules aren't offered
    library_groups = schema.get("x-libraryGroups", [])
    for definition in ("BarWidget", "OverlayModule"):
        for option in schema["definitions"][definition]["oneOf"]:
            name = option.get("$ref", "").split("/")[-1]
            target = schema["definitions"].get(name, option)
            if target.get("x-required"):
                continue
            group = target.get("x-libraryGroup")
            if group not in library_groups:
                errors.append(f"{definition} {name}: x-libraryGroup {group!r} isn't one of the schema's x-libraryGroups")

    # Hand-built settings parts: x-card loads views/settings/<Name>Card.qml,
    # x-intro views/settings/<Name>.qml (by URL, so a typo only shows in the log)
    def annotated(node, found):
        if isinstance(node, dict):
            for key, value in node.items():
                if key in ("x-card", "x-intro"):
                    found.append((key, value))
                annotated(value, found)
        elif isinstance(node, list):
            for value in node:
                annotated(value, found)
        return found
    for key, name in annotated(schema, []):
        target = f"components/views/settings/{name}{'Card' if key == 'x-card' else ''}.qml"
        if not (ROOT / target).exists():
            errors.append(f"schema {key} {name!r} has no {target}")

    # Tool pages (x-tool) are always in config: the Overlay.views default
    # carries every one (and a migration adds a new one to existing configs)
    default_views = {v.get("type") for v in schema["properties"]["Overlay"]["properties"]["views"]["default"]}
    for option in schema["definitions"]["OverlayView"]["oneOf"]:
        target = schema["definitions"].get(option.get("$ref", "").split("/")[-1], option)
        if target.get("x-tool"):
            const = target["properties"]["type"]["const"]
            if const not in default_views:
                errors.append(f"tool page {const} isn't in the Overlay.views default")

    # Every IPC target is in docs/usage.md's IPC table, and the table names
    # no target that's gone
    targets = {}
    for path, text in sources.items():
        for m in re.finditer(r"IpcHandler\s*\{", text):
            found = re.search(r'target:\s*"(\w+)"', text[m.end():m.end() + 400])
            if found:
                targets.setdefault(found.group(1), path)
    usage = (ROOT / "docs/usage.md").read_text()
    table = usage[usage.find("<summary><b>IPC targets"):]
    table = table[:table.find("</details>")]
    listed = set(re.findall(r"^\| `(\w+)`", table, re.M))
    for target, path in sorted(targets.items()):
        if target not in listed:
            errors.append(f"{path}: IPC target {target!r} is missing from the IPC table in docs/usage.md")
    for target in sorted(listed - set(targets)):
        errors.append(f"docs/usage.md: IPC target {target!r} has no IpcHandler")

    # Every file says what it's for above its root object (docs/dev/generated/files.md)
    for path, text in sources.items():
        lines = text.split("\n")
        start = next((i for i, line in enumerate(lines) if re.match(r"[A-Z][\w.]*\s*\{", line)), None)
        if start is None:
            continue
        j = start - 1
        while j >= 0 and not lines[j].strip():
            j -= 1
        if j < 0 or not (lines[j].startswith("//") or lines[j].rstrip().endswith("*/")):
            errors.append(f"{path}: no purpose comment above its root object")

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

    # Every file starts with `pragma ComponentBehavior: Bound` (delegates see
    # only their required properties, and ids in nested components resolve)
    # or `pragma Singleton`
    for path, text in sources.items():
        # the first line that isn't a comment (a header, qs's //@ pragmas)
        head = next((line.strip() for line in text.split("\n") if line.strip() and not line.strip().startswith("//")), "")
        if head not in ("pragma ComponentBehavior: Bound", "pragma Singleton"):
            errors.append(f"{path}: doesn't start with pragma ComponentBehavior: Bound (or pragma Singleton)")

    # qs.* imports resolve
    for path, text in sources.items():
        for m in re.finditer(r"^import (qs(?:\.\w+)+)", text, re.M):
            target = ROOT.joinpath(*m.group(1).split(".")[1:])
            if not target.is_dir():
                errors.append(f"{path}: import {m.group(1)} — no such directory")

    # Only the Hyprland* services read Quickshell.Hyprland: the rest goes
    # through HyprlandManager (docs/dev/hyprland/ipc.md)
    for path, text in sources.items():
        if re.search(r"^import Quickshell\.Hyprland\b", text, re.M) and not re.fullmatch(r"services/Hyprland\w*\.qml", path):
            errors.append(f"{path}: imports Quickshell.Hyprland (only the Hyprland* services may; use CompositorManager)")

    # Likewise only the Sway* services read Quickshell.I3, run swaymsg or use
    # SwayManager directly (docs/dev/compositor/sway-backend.md)
    for path, text in sources.items():
        if re.fullmatch(r"services/Sway\w*\.qml", path) or path == "services/CompositorManager.qml":
            continue
        code = "\n".join(line.split("//", 1)[0] for line in text.splitlines())
        if re.search(r"^import Quickshell\.I3\b", text, re.M):
            errors.append(f"{path}: imports Quickshell.I3 (only the Sway* services may; use CompositorManager)")
        if re.search(r"\bSwayManager\.|\bSwayIpcManager\.|\"swaymsg\"", code):
            errors.append(f"{path}: talks to sway directly (only the Sway* services may; use CompositorManager)")

    # The rest of the shell reaches the compositor through CompositorManager
    # (docs/dev/compositor/README.md). HyprlandManager is its Hyprland
    # backend; besides the Hyprland* services, only the Hyprland-only
    # features use it directly, each gated on CompositorManager.supports.
    hyprland_features = {
        "services/CompositorManager.qml", "services/GreetdManager.qml", "services/OnboardingManager.qml",
    }
    for path, text in sources.items():
        code = "\n".join(line.split("//", 1)[0] for line in text.splitlines())
        if re.search(r"\bHyprlandManager\.", code) and not re.fullmatch(r"services/Hyprland\w*\.qml", path) and path not in hyprland_features:
            errors.append(f"{path}: uses HyprlandManager (only the Hyprland* services and the Hyprland-only features may; use CompositorManager)")

    # A backend's text and state helpers are its own (Hyprland's Lua,
    # sway's commands): outside its services and helpers (and the
    # Hyprland-only features), the rest of the shell goes through
    # CompositorManager and CompositorConfigManager
    # (docs/dev/compositor/config-modes.md)
    for path, text in sources.items():
        code = "\n".join(line.split("//", 1)[0] for line in re.sub(r"/\*.*?\*/", "", text, flags=re.S).splitlines())
        if not path.startswith(("services/", "components/", "shell/", "config/")):
            continue
        if not re.fullmatch(r"(services|components/methods)/Hypr\w*\.qml", path) and path not in hyprland_features and re.search(r"\b(HyprLua|HyprConfigLua|HyprState)\.", code):
            errors.append(f"{path}: uses a Hyprland Lua helper (only the Hyprland* services and helpers may; go through CompositorManager / CompositorConfigManager)")
        if not re.fullmatch(r"(services|components/methods)/Sway\w*\.qml", path) and re.search(r"\b(SwayConf|SwayState)\.", code):
            errors.append(f"{path}: uses a sway helper (only the Sway* services and helpers may; go through CompositorManager / CompositorConfigManager)")

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

    # Readers: the schema fills every default, so `_c.key ?? x` is dead
    for path, text in sources.items():
        if not path.startswith("config/"):
            continue
        for n, line in enumerate(re.sub(r"//[^\n]*", "", text).splitlines(), 1):
            m = re.search(r"\b_c(?:\.\w+)+\s*\?\?", line)
            if m:
                errors.append(f"{path}:{n}: `{m.group(0)}`: readers use no ?? fallback (the schema default is filled at load)")

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
