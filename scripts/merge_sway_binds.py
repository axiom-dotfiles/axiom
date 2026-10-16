#!/usr/bin/env python3
"""Moves the binds in a managed sway config's user/* files into axiom.

merge_hypr_binds.py's counterpart, with the same JSON, so SwayBindMerge
handles it as HyprlandBindMerge does.

  merge_sway_binds.py extract <sway dir> [--only <file name>]
      Prints JSON: { binds, sites, kept, remapped, tracked, errors }
        binds    axiom binds (Keybinds.binds entries) for every bindsym or
                 bindcode line outside a mode that can move: an axiom
                 action where one does the same, `exec` for a command,
                 else the `raw` action (compositor sway) with the command
                 as written
        sites    [{ file, line, binds }]: the lines those come from
        kept     [{ file, line, key, reason, detail }]: binds that stay
        remapped []  (sway has no example binds axiom's defaults move off)
        tracked  [file]: files read that are in a git repository
        errors   []
      Files are read in name order, as sway includes them, with the
      $variables set in each so far. --only reads just that file of user/.
      Writes nothing.

  merge_sway_binds.py remove <sway dir> <sites JSON, as extract printed>
      Comments those lines out ("# (moved into axiom) "), after a dated
      backup of each file it changes beside it (in user/, as
      <file>.axiom-backup-<date>, which the managed config's include of
      user/* would load: so the backups go to user/.backups/). Prints
      JSON: { removed, files, failed: [{ file, line, reason, detail }] }
      A line that changed since extract is left (reason `changed`).

Reason codes: options (sway options axiom binds don't have: detail),
key (its key can't be read), continued (a line continued with \\).
"""
import json
import re
import shutil
import subprocess
import sys
import time
from pathlib import Path

MODS = {"mod4": "SUPER", "super": "SUPER", "mod1": "ALT", "alt": "ALT", "ctrl": "CTRL", "control": "CTRL",
        "shift": "SHIFT", "lock": "CAPS", "mod2": "MOD2", "mod3": "MOD3", "mod5": "MOD5"}
MOUSE = {"button1": "mouse:272", "button2": "mouse:274", "button3": "mouse:273", "button4": "mouse_up",
         "button5": "mouse_down", "button6": "mouse_left", "button7": "mouse_right", "btn_left": "mouse:272",
         "btn_right": "mouse:273", "btn_middle": "mouse:274", "btn_side": "mouse:275", "btn_extra": "mouse:276"}
# Options a moved bind can keep; anything else keeps the bind in its file
FLAGS = {"--release": "release", "--locked": "locked"}
HARMLESS = {"--no-warn", "--whole-window", "--no-repeat", "--to-code"}
DIRECTIONS = {"left", "right", "up", "down"}
MARK = "# (moved into axiom) "
ROOT = Path(__file__).resolve().parent.parent
# What a call names, for actions that open and close (BindActions.calls)
CALLS = {"toggle": "toggle", "open": "open", "show": "open", "enable": "open",
         "close": "close", "hide": "close", "disable": "close"}


def ipc_actions():
    """BindActions.ipcActions as [(action, regex)]: each IPC call, its
    {call} and {0} as groups."""
    text = (ROOT / "components/methods/BindActions.qml").read_text()
    table = text[text.index("ipcActions:"):text.index("compositorActions:")]
    actions = []
    for name, call in re.findall(r'"(\w+)": \["([^"]+)"', table):
        pattern = re.escape(call).replace(re.escape("{call}"), r"(?P<call>\w+)").replace(re.escape("{0}"), r"(?P<arg>\S+)")
        actions.append((name, re.compile(pattern + "$")))
    return actions


IPC = ipc_actions()


def repeating_actions():
    """The actions axiom repeats while held by default (BindActions.actionFlags)."""
    text = (ROOT / "components/methods/BindActions.qml").read_text()
    table = text[text.index("actionFlags:"):text.index("flagNames:")]
    return {name for name, flags in re.findall(r'"(\w+)": \[([^\]]*)\]', table) if '"repeating"' in flags}


REPEATING = repeating_actions()
# axiom started or called over IPC: qs -c axiom / qs -p <…axiom>
SHELL = r"""(?:qs|quickshell) +(?:-c +axiom|-p +['"]?\S*axiom['"]?)"""


def ipc_action(command):
    """The axiom action an `exec` of an IPC call is, or None."""
    if re.fullmatch(r"(?:qs|quickshell) +kill +.*;\s*" + SHELL + r" +-d", command):
        return {"action": "restartShell"}
    match = re.fullmatch(SHELL + r" +ipc +call +(.+)", command)
    if not match:
        return None
    call = match.group(1).strip()
    for name, pattern in IPC:
        found = pattern.match(call)
        if found:
            entry = {"action": name}
            groups = found.groupdict()
            if groups.get("call"):
                entry["call"] = CALLS.get(groups["call"], "toggle")
            if groups.get("arg"):
                entry["argument"] = unquote(groups["arg"])
            return entry
    return None


def axiom_key(combo, code):
    parts = [p for p in combo.split("+") if p]
    if not parts:
        return None
    mods = []
    for mod in parts[:-1]:
        name = MODS.get(mod.lower())
        if not name:
            return None
        mods.append(name)
    last = parts[-1]
    if code:
        if not last.isdigit():
            return None
        key = "code:" + last
    else:
        key = MOUSE.get(last.lower(), last.upper() if len(last) == 1 else last)
    order = ["SUPER", "CTRL", "ALT", "SHIFT", "CAPS", "MOD2", "MOD3", "MOD5"]
    mods.sort(key=order.index)
    return " + ".join(mods + [key])


def unquote(text):
    text = text.strip()
    if len(text) >= 2 and text[0] == text[-1] and text[0] in "\"'":
        return text[1:-1]
    return text


def action_for(command):
    words = command.split()
    if command == "kill":
        return {"action": "closeWindow"}
    if command in ("fullscreen", "fullscreen toggle"):
        return {"action": "fullscreen"}
    if command == "floating toggle":
        return {"action": "toggleFloat"}
    if command == "sticky toggle":
        return {"action": "pin"}
    if command == "layout toggle split":
        return {"action": "toggleSplit"}
    if command == "move position center":
        return {"action": "centerWindow"}
    if command == "exit":
        return {"action": "exitSession"}
    if len(words) == 2 and words[0] == "focus" and words[1] in DIRECTIONS:
        return {"action": "focusDir", "argument": words[1]}
    if len(words) == 2 and words[0] == "move" and words[1] in DIRECTIONS:
        return {"action": "moveWindowDir", "argument": words[1]}
    if words and words[0] == "exec":
        argument = unquote(command[4:])
        return ipc_action(argument) or {"action": "exec", "argument": argument}
    return {"action": "raw", "argument": command, "compositor": "sway"}


def expand(text, variables):
    for name in sorted(variables, key=len, reverse=True):
        text = text.replace(name, variables[name])
    return text


def in_git(path):
    return subprocess.run(["git", "-C", str(path.parent), "rev-parse", "--show-toplevel"],
                          capture_output=True, text=True).returncode == 0


def user_files(sway, only):
    user = sway / "user"
    if only:
        return [user / only] if (user / only).is_file() else []
    return sorted(p for p in user.iterdir() if p.is_file() and ".axiom-backup-" not in p.name) if user.is_dir() else []


def extract(sway, only):
    result = {"binds": [], "sites": [], "kept": [], "remapped": [], "tracked": [], "errors": []}
    variables = {}
    for path in user_files(sway, only):
        if in_git(path):
            result["tracked"].append(str(path))
        depth = 0
        lines = path.read_text(errors="replace").splitlines()
        for number, raw in enumerate(lines, 1):
            line = raw.strip()
            if not line or line.startswith("#"):
                continue
            var = re.match(r"set\s+(\$\S+)\s+(.*)$", line)
            if var:
                variables[var.group(1)] = expand(var.group(2), variables).strip()
                continue
            if line.endswith("{"):
                depth += 1
                continue
            if line == "}":
                depth = max(0, depth - 1)
                continue
            bind = re.match(r"(bindsym|bindcode)\s+(.*)$", line)
            if not bind or depth > 0:
                continue
            words = expand(bind.group(2), variables).split()
            flags = []
            while words and words[0].startswith("--"):
                flags.append(words.pop(0))
            combo = words.pop(0) if words else ""
            command = " ".join(words)
            site = {"file": str(path), "line": number}
            if raw.rstrip().endswith("\\"):
                result["kept"].append({**site, "key": combo, "reason": "continued", "detail": ""})
                continue
            other = [f for f in flags if f not in FLAGS and f not in HARMLESS and not f.startswith("--input-device")]
            if other or any(f.startswith("--input-device") for f in flags):
                result["kept"].append({**site, "key": combo, "reason": "options", "detail": " ".join(other or flags)})
                continue
            key = axiom_key(combo, bind.group(1) == "bindcode")
            if not key or not command:
                result["kept"].append({**site, "key": combo, "reason": "key", "detail": ""})
                continue
            entry = {"key": key, **action_for(command)}
            for flag, name in FLAGS.items():
                if flag in flags:
                    entry[name] = True
            # Sway repeats a held bind unless told not to, but that's rarely
            # meant (a held close would close one window after another):
            # an action repeats as axiom's own does, a raw command as sway
            # had it
            if "--no-repeat" not in flags and (entry["action"] in REPEATING or entry["action"] == "raw"):
                entry["repeating"] = True
            result["binds"].append(entry)
            result["sites"].append({**site, "binds": [entry], "text": raw})
    return result


def remove(sway, sites):
    done = {"removed": 0, "files": [], "failed": []}
    by_file = {}
    for site in sites:
        by_file.setdefault(site["file"], []).append(site)
    stamp = time.strftime("%Y%m%d-%H%M%S")
    for name, file_sites in by_file.items():
        path = Path(name)
        if path.parent != sway / "user" or not path.is_file():
            done["failed"].append({"file": name, "line": 0, "reason": "notUser", "detail": ""})
            continue
        lines = path.read_text(errors="replace").splitlines(keepends=True)
        changed = False
        for site in file_sites:
            i = site["line"] - 1
            if i >= len(lines) or lines[i].rstrip("\n") != site.get("text", lines[i].rstrip("\n")):
                done["failed"].append({"file": name, "line": site["line"], "reason": "changed", "detail": ""})
                continue
            lines[i] = MARK + lines[i]
            done["removed"] += 1
            changed = True
        if changed:
            backups = sway / "user" / ".backups"
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
