#!/usr/bin/env python3
"""Moves the binds in a managed niri config's user/*.kdl files into axiom.

merge_sway_binds.py's counterpart, with the same verbs and JSON, so the
same UserBindMerge runs either.

  merge_niri_binds.py extract <niri dir> [--only <file name>]
      Prints JSON: { binds, sites, kept, remapped, tracked, errors }
        binds    axiom binds (Keybinds.binds entries) for every bind in a
                 top-level `binds` block that can move: an axiom action
                 where one does the same (axiom's own IPC calls, volume,
                 brightness and media commands among them), `exec` for any
                 other spawn, else the `raw` action (compositor niri) with
                 the action as niri's config writes it
        sites    [{ file, line, col, binds, text }]: the binds those come
                 from (`text`: the line as read)
        kept     [{ file, line, key, reason, detail }]: binds that stay
        remapped []  (niri's default config is only backed up, not adopted)
        tracked  [file]: files read that are in a git repository
        errors   [{ file, detail }]: files that don't parse (nothing of them
                 moves)
      Files are read in name order, as the managed config includes them.
      --only reads just that file of user/. Writes nothing.

  merge_niri_binds.py remove <niri dir> <sites JSON, as extract printed>
      Comments those binds out (MARK before each: KDL's /- takes the whole
      node out, its block too), after a dated backup of each file it
      changes in user/.backups/. Prints JSON:
      { removed, files, failed: [{ file, line, reason, detail }] }
      A bind whose line changed since extract is left (reason `changed`).

Reason codes: options (niri bind options axiom binds don't have: detail),
key (its key can't be written as axiom's), notUser (not one of user/*.kdl).
"""
import json
import shlex
import shutil
import sys
import time
from pathlib import Path

import niri_kdl
from bind_merge_common import REPEATING, in_git, ipc_action, media_action

MARK = "/* (moved into axiom) */ /-"
# Options a moved bind can keep (as axiom's flags or its label); anything
# else keeps the bind in its file
HARMLESS = {"repeat", "cooldown-ms", "hotkey-overlay-title", "allow-when-locked"}

# niri's actions that are an axiom action of their own
SIMPLE = {"close-window": "closeWindow", "fullscreen-window": "fullscreen", "toggle-window-floating": "toggleFloat",
          "center-window": "centerWindow", "quit": "exitSession", "toggle-column-tabbed-display": "toggleGroup",
          "expand-column-to-available-width": "stripFit"}
# niri's actions taking a direction: (axiom action, direction)
DIRECTIONAL = {
    "focus-column-left": ("focusDir", "left"), "focus-column-right": ("focusDir", "right"),
    "focus-column-or-monitor-left": ("focusDir", "left"), "focus-column-or-monitor-right": ("focusDir", "right"),
    "focus-window-up": ("focusDir", "up"), "focus-window-down": ("focusDir", "down"),
    "focus-window-or-monitor-up": ("focusDir", "up"), "focus-window-or-monitor-down": ("focusDir", "down"),
    "move-column-left": ("stripSwapColumn", "left"), "move-column-right": ("stripSwapColumn", "right"),
    "move-column-left-or-to-monitor-left": ("moveWindowDir", "left"),
    "move-column-right-or-to-monitor-right": ("moveWindowDir", "right"),
    "move-window-up": ("moveWindowDir", "up"), "move-window-down": ("moveWindowDir", "down"),
    "focus-workspace-down": ("workspaceStep", "down"), "focus-workspace-up": ("workspaceStep", "up"),
    "move-column-to-workspace-down": ("moveWindowStep", "down"),
    "move-column-to-workspace-up": ("moveWindowStep", "up"),
    "move-window-to-workspace-down": ("moveWindowStep", "down"),
    "move-window-to-workspace-up": ("moveWindowStep", "up"),
}
# niri's actions taking a workspace number (its index on the output, as
# axiom's nth is)
NUMBERED = {"focus-workspace": "workspaceNth", "move-column-to-workspace": "moveWindowNth",
            "move-window-to-workspace": "moveWindowNth"}


def command_action(command):
    """An axiom action for a command niri runs, `exec` at least."""
    return ipc_action(command) or ({"action": media} if (media := media_action(command)) else None) or \
        {"action": "exec", "argument": command}


def action_for(node):
    """The axiom action a bind's action node is."""
    args = node.args
    # (quit asks first unless skip-confirmation: axiom's log out doesn't)
    if node.name == "quit" or (node.name in SIMPLE and not args and not node.props):
        return {"action": SIMPLE[node.name]}
    if node.name in DIRECTIONAL and not args and not node.props:
        action, direction = DIRECTIONAL[node.name]
        return {"action": action, "argument": direction}
    if node.name in NUMBERED and len(args) == 1 and isinstance(args[0], int) and args[0] >= 1 \
            and not node.props.get("focus") is False:
        return {"action": NUMBERED[node.name], "argument": str(args[0])}
    if node.name == "set-column-width" and args in (["+10%"], ["-10%"]):
        return {"action": "stripWider" if args[0].startswith("+") else "stripNarrower"}
    if node.name == "spawn" and args and all(isinstance(a, str) for a in args):
        return command_action(shlex.join(args) if len(args) > 1 else args[0])
    if node.name == "spawn-sh" and len(args) == 1 and isinstance(args[0], str):
        return command_action(args[0])
    return {"action": "raw", "argument": niri_kdl.node_text(node), "compositor": "niri"}


def user_files(niri, only):
    user = niri / "user"
    if only:
        return [user / only] if (user / only).is_file() else []
    # As the managed config includes them: .kdl files, no hidden ones (a
    # staged write, an editor's swap file) or backups
    return sorted(p for p in user.glob("*.kdl") if p.is_file() and not p.name.startswith(".")) if user.is_dir() else []


def extract(niri, only):
    result = {"binds": [], "sites": [], "kept": [], "remapped": [], "tracked": [], "errors": []}
    parsed = []
    for path in user_files(niri, only):
        text = path.read_text(errors="replace")
        try:
            parsed.append((path, text, niri_kdl.parse(text)))
        except niri_kdl.KdlError as error:
            result["errors"].append({"file": str(path), "detail": str(error)})
    mod = niri_kdl.mod_key([(path, nodes) for path, _, nodes in parsed], niri_kdl.running_nested())
    for path, text, nodes in parsed:
        lines = text.splitlines()
        if in_git(path):
            result["tracked"].append(str(path))
        for block in nodes:
            if block.name != "binds":
                continue
            for bind in block.children or []:
                site = {"file": str(path), "line": bind.line}
                other = sorted(k for k in bind.props if k not in HARMLESS)
                if other:
                    result["kept"].append({**site, "key": bind.name, "reason": "options", "detail": " ".join(other)})
                    continue
                key = niri_kdl.axiom_key(bind.name, mod)
                action = (bind.children or [None])[0]
                if not key or action is None:
                    result["kept"].append({**site, "key": bind.name, "reason": "key", "detail": ""})
                    continue
                entry = {"key": key, **action_for(action)}
                if bind.props.get("allow-when-locked") is True:
                    entry["locked"] = True
                if bind.props.get("hotkey-overlay-title"):
                    entry["description"] = str(bind.props["hotkey-overlay-title"])
                # niri repeats a held bind unless told not to, but that's
                # rarely meant (a held close would close one window after
                # another): an action repeats as axiom's own does, a raw
                # one as niri had it
                if bind.props.get("repeat") is not False and (entry["action"] in REPEATING or entry["action"] == "raw"):
                    entry["repeating"] = True
                result["binds"].append(entry)
                result["sites"].append({**site, "col": bind.col, "binds": [entry], "text": lines[bind.line - 1]})
    return result


def remove(niri, sites):
    done = {"removed": 0, "files": [], "failed": []}
    by_file = {}
    for site in sites:
        by_file.setdefault(site["file"], []).append(site)
    stamp = time.strftime("%Y%m%d-%H%M%S")
    for name, file_sites in by_file.items():
        path = Path(name)
        if path.parent != niri / "user" or not path.is_file():
            done["failed"].append({"file": name, "line": 0, "reason": "notUser", "detail": ""})
            continue
        lines = path.read_text(errors="replace").splitlines(keepends=True)
        changed = False
        # Right to left, so a column still points where it did
        for site in sorted(file_sites, key=lambda s: (s["line"], s["col"]), reverse=True):
            i, col = site["line"] - 1, site["col"]
            if i >= len(lines) or lines[i].rstrip("\r\n") != site.get("text", lines[i].rstrip("\r\n")):
                done["failed"].append({"file": name, "line": site["line"], "reason": "changed", "detail": ""})
                continue
            lines[i] = lines[i][:col] + MARK + lines[i][col:]
            done["removed"] += 1
            changed = True
        if changed:
            backups = niri / "user" / ".backups"
            backups.mkdir(exist_ok=True)
            shutil.copy2(path, backups / f"{path.name}.axiom-backup-{stamp}")
            staged = path.with_name("." + path.name + ".axiom-tmp")
            staged.write_text("".join(lines))
            shutil.copymode(path, staged)
            staged.replace(path)
            done["files"].append(name)
    return done


def main(argv):
    if len(argv) >= 2 and argv[0] == "extract":
        only = argv[argv.index("--only") + 1] if "--only" in argv else ""
        print(json.dumps(extract(Path(argv[1]), only)))
        return 0
    if len(argv) == 3 and argv[0] == "remove":
        print(json.dumps(remove(Path(argv[1]), json.loads(argv[2]))))
        return 0
    print(__doc__, file=sys.stderr)
    return 2


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
