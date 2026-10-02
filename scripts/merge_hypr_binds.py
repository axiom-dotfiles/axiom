#!/usr/bin/env python3
"""Moves the binds in a managed Hyprland config's user/*.lua into axiom.

  merge_hypr_binds.py extract <hypr dir> [--only <file name>]
      Prints JSON: { binds, sites, kept, remapped, tracked, errors }
        binds    axiom binds (Hyprland.binds entries) for every bind that
                 can move: an axiom action where one does the same (the
                 bind actions cover Hyprland's example config), else the
                 `lua` action with the dispatcher as written
        sites    [{ file, line, binds }]: the hl.bind calls those come from
                 (`binds`: the ones each makes), plus the hl.unbind calls on
                 their keys (which would otherwise unbind the moved binds
                 too, since user/ loads after axiom; `binds` empty)
        kept     [{ file, line, key, reason, detail }]: binds that stay
                 where they are, `reason` a code (see below)
        remapped [{ from, to, action }]: binds from the adopted config
                 (ADOPTED) moved off a key axiom's defaults use
                 (EXAMPLE_KEYS)
        tracked  [file]: files read that are in a git repository
        errors   the files' own errors, from running them
      --only reads just that file of user/ (the one a takeover adopted).
      Writes nothing.

  merge_hypr_binds.py remove <hypr dir> <sites JSON, as extract printed>
      Deletes those calls (each whole statement, with its line when nothing
      else is on it), after a dated backup of each file it changes beside it
      (<file>.axiom-backup-<date>, which Hyprland doesn't load). A file
      whose result `luac -p` rejects is left alone. Prints JSON:
      { removed, files, failed: [{ file, line, reason, detail }] }
      `line` is 0 when the whole file was left alone; else that one call
      wasn't found. Every moved bind from a failed site is still in the
      file, so the caller takes it back out of axiom's.

Reason codes (kept and failed): key (its key isn't plain text), function
(it runs a Lua function), options (axiom binds don't have its options:
detail), shared (made in a shared module), notOnly (not the only call on
its line), statement (part of a larger statement), followed (something
else follows it on its line), used (kept in a variable the file uses:
detail), unclosed (the call isn't closed), changed (the file changed),
notUser (not one of user/*.lua), syntax (the result doesn't parse:
detail).

A bind moves only when every bind its call makes can (a call in a loop
makes several), the call is the whole statement, and it's in a user/*.lua
file itself (not a shared module). Binds inside submaps or hl.on handlers
aren't seen, since those functions never run here.
"""
import json
import re
import shutil
import subprocess
import sys
import time
from pathlib import Path

SCRIPTS = Path(__file__).resolve().parent
EXTRACTOR = SCRIPTS / "hypr_binds.lua"

# The files a takeover moves the previous hyprland.lua to (00-previous.lua,
# or 00-previous-<date>.lua when that's taken)
ADOPTED = re.compile(r"00-previous(-[0-9-]+)?\.lua")
EXIT_COMMAND = "command -v hyprshutdown >/dev/null 2>&1 && hyprshutdown || hyprctl dispatch 'hl.dsp.exit()'"
DIRECTIONS = ("left", "right", "up", "down")
# Bind options axiom's binds carry; `mouse` comes with a mouse: key by itself
FLAGS = ("locked", "repeating", "release")
KNOWN_OPTS = set(FLAGS) | {"mouse", "description"}
# Hyprland's example config's binds that move to another key, where theirs
# would take one of axiom's defaults (SUPER + J is focus down, SUPER + S and
# SUPER + SHIFT + S WASD's workspace and window down): (key_id, action) ->
# key. Its float leaves SUPER + V for the special workspace, onto axiom's.
# Only for binds in ADOPTED: elsewhere a key was the user's own choice.
EXAMPLE_KEYS = {
    ("super + j", "toggleSplit"): "SUPER + X",
    ("super + s", "toggleSpecial"): "SUPER + V",
    ("shift + super + s", "moveToSpecial"): "SUPER + SHIFT + V",
    ("super + v", "toggleFloat"): "SUPER + Z",
}


# --- Mapping ---

def _step(workspace):
    """A relative workspace ("e+1", "+1", "r-1", "m+1") as left/right."""
    match = re.fullmatch(r"[erm]?([+-])1", str(workspace))
    return None if not match else ("right" if match.group(1) == "+" else "left")


def _number(workspace):
    if isinstance(workspace, bool):
        return None
    if isinstance(workspace, (int, float)) and int(workspace) == workspace and workspace >= 1:
        return str(int(workspace))
    if isinstance(workspace, str) and re.fullmatch(r"[1-9][0-9]*", workspace):
        return workspace
    return None


def _exec_action(command):
    """An exec_cmd's command as an axiom action, when one does the same."""
    command = command.strip()
    if command == EXIT_COMMAND:
        return "exitHyprland", ""
    words = command.split()
    if not words:
        return None
    tool, rest = words[0], " ".join(words[1:])
    if tool == "wpctl":
        if re.fullmatch(r"set-volume( -l [0-9.]+)? @DEFAULT_AUDIO_SINK@ [0-9.]+%?\+", rest):
            return "volumeUp", ""
        if re.fullmatch(r"set-volume( -l [0-9.]+)? @DEFAULT_AUDIO_SINK@ [0-9.]+%?-", rest):
            return "volumeDown", ""
        if rest == "set-mute @DEFAULT_AUDIO_SINK@ toggle":
            return "toggleMute", ""
        if rest == "set-mute @DEFAULT_AUDIO_SOURCE@ toggle":
            return "toggleMicMute", ""
    if tool == "pactl":
        if re.fullmatch(r"set-sink-volume @DEFAULT_SINK@ \+[0-9]+%", rest):
            return "volumeUp", ""
        if re.fullmatch(r"set-sink-volume @DEFAULT_SINK@ -[0-9]+%", rest):
            return "volumeDown", ""
        if rest == "set-sink-mute @DEFAULT_SINK@ toggle":
            return "toggleMute", ""
        if rest == "set-source-mute @DEFAULT_SOURCE@ toggle":
            return "toggleMicMute", ""
    if tool == "brightnessctl":
        if re.fullmatch(r"(-\S+ )*set [0-9]+%\+", rest):
            return "brightnessUp", ""
        if re.fullmatch(r"(-\S+ )*set [0-9]+%-", rest):
            return "brightnessDown", ""
    if tool == "playerctl":
        media = {"play-pause": "mediaPlayPause", "next": "mediaNext", "previous": "mediaPrevious", "stop": "mediaStop"}
        if rest in media:
            return media[rest], ""
    return "exec", command


def map_dispatcher(name, args):
    """(action, argument) for a dispatcher and its arguments."""
    one = args[0] if len(args) == 1 else None
    table = one if isinstance(one, dict) else None
    if name == "exec_cmd" and isinstance(one, str):
        return _exec_action(one)
    if not args:
        simple = {"window.close": "closeWindow", "window.pseudo": "pseudo", "window.fullscreen": "fullscreen",
                  "window.pin": "pin", "window.center": "centerWindow", "group.toggle": "toggleGroup",
                  "window.drag": "mouseDrag", "window.resize": "mouseResize"}
        if name in simple:
            return simple[name], ""
    if name == "layout" and one == "togglesplit":
        return "toggleSplit", ""
    if name == "workspace.toggle_special" and isinstance(one, str) and one:
        return "toggleSpecial", one
    if table is not None and len(table) == 1:
        (key, value), = table.items()
        if name == "window.float" and key == "action" and value == "toggle":
            return "toggleFloat", ""
        if name == "focus" and key == "direction" and value in DIRECTIONS:
            return "focusDir", value
        if name == "window.move" and key == "direction" and value in DIRECTIONS:
            return "moveWindowDir", value
        if name in ("focus", "window.move") and key == "workspace":
            go = name == "focus"
            if _number(value):
                return ("workspaceNth" if go else "moveWindowNth"), _number(value)
            if _step(value):
                return ("workspaceStep" if go else "moveWindowStep"), _step(value)
            if not go and isinstance(value, str) and value.startswith("special:") and len(value) > 8:
                return "moveToSpecial", value[8:]
    if name == "window.resize" and table is not None and set(table) == {"x", "y", "relative"} and table["relative"] is True:
        if all(isinstance(table[k], (int, float)) and not isinstance(table[k], bool) for k in ("x", "y")):
            return "resizeWindow", f"{table['x']:g} {table['y']:g}"
    return None


def to_axiom(entry, adopted=False):
    """The axiom bind for an extracted bind, or (None, (reason, detail)).
    `adopted`: it's from ADOPTED, so EXAMPLE_KEYS applies."""
    if not entry.get("key"):
        return None, ("key", "")
    if not entry.get("lua"):
        return None, ("function", "")
    opts = entry.get("opts") or {}
    unknown = sorted(set(opts) - KNOWN_OPTS)
    if unknown:
        return None, ("options", ", ".join(unknown))
    mapped = map_dispatcher(entry["dispatcher"], entry.get("args") or [])
    action, argument = mapped if mapped else ("lua", entry["lua"])
    key = EXAMPLE_KEYS.get((key_id(entry["key"]), action), entry["key"]) if adopted else entry["key"]
    bind = {"key": key, "action": action, "argument": argument, "call": "toggle"}
    for flag in FLAGS:
        bind[flag] = opts.get(flag) is True
    description = opts.get("description")
    bind["description"] = description if isinstance(description, str) else ""
    return bind, None


def key_id(key):
    """A key with its modifiers in a fixed order, for comparing."""
    parts = [p.strip().lower() for p in re.split(r"\s*\+\s*", str(key or "").strip()) if p.strip()]
    return " + ".join(sorted(parts[:-1]) + parts[-1:]) if parts else ""


# --- Lua source ---

def _long_bracket(text, i):
    """The length of a long bracket opening at i ("[[", "[==["), else 0."""
    match = re.match(r"\[(=*)\[", text[i:])
    return len(match.group(0)) if match else 0


def _skip(text, i):
    """If a string or comment starts at i, the index after it; else None."""
    c = text[i]
    if c in "\"'":
        j = i + 1
        while j < len(text) and text[j] != c:
            if text[j] == "\\":
                j += 1
            elif text[j] == "\n":
                return j
            j += 1
        return j + 1
    if text.startswith("--", i):
        n = _long_bracket(text, i + 2)
        if n:
            end = text.find("]" + "=" * (n - 2) + "]", i + 2 + n)
            return len(text) if end < 0 else end + n
        end = text.find("\n", i)
        return len(text) if end < 0 else end
    if c == "[":
        n = _long_bracket(text, i)
        if n:
            end = text.find("]" + "=" * (n - 2) + "]", i + n)
            return len(text) if end < 0 else end + n
    return None


def code_only(text):
    """The text with strings and comments blanked out (newlines kept), so
    positions still line up."""
    out = list(text)
    i = 0
    while i < len(text):
        end = _skip(text, i)
        if end is None:
            i += 1
            continue
        for j in range(i, min(end, len(text))):
            if out[j] != "\n":
                out[j] = " "
        i = end
    return "".join(out)


def statement_span(text, code, line, call):
    """(start, end) offsets of the statement made of the `call` ("hl.bind")
    call starting on 1-based `line`, with the whole line when nothing else
    is on it, or (None, (reason, detail))."""
    starts = [0] + [m.end() for m in re.finditer("\n", text)]
    if line < 1 or line > len(starts):
        return None, ("changed", "")
    line_start = starts[line - 1]
    line_end = starts[line] - 1 if line < len(starts) else len(text)
    found = [m for m in re.finditer(re.escape(call) + r"\s*\(", code[line_start:line_end])]
    if len(found) != 1:
        return None, ("notOnly" if found else "changed", "")
    open_paren = line_start + found[0].end() - 1
    depth = 0
    close = None
    for i in range(open_paren, len(code)):
        if code[i] == "(":
            depth += 1
        elif code[i] == ")":
            depth -= 1
            if depth == 0:
                close = i
                break
    if close is None:
        return None, ("unclosed", "")
    before = code[line_start:line_start + found[0].start()]
    assigned = re.fullmatch(r"\s*(?:local\s+)?([A-Za-z_]\w*)\s*=\s*", before)
    if before.strip() and not assigned:
        return None, ("statement", "")
    after_end = code.find("\n", close)
    after_end = len(code) if after_end < 0 else after_end
    if code[close + 1:after_end].strip() not in ("", ";"):
        return None, ("followed", "")
    if assigned:
        name = assigned.group(1)
        rest = code[:line_start] + code[after_end:]
        if re.search(r"(?<![\w.:])" + re.escape(name) + r"\b", rest):
            return None, ("used", name)
    end = after_end + 1 if after_end < len(text) else after_end
    return (line_start, end), None


# --- Commands ---

def _modules(hypr, only=None):
    user = hypr / "user"
    files = sorted(p for p in user.glob("*.lua") if p.is_file()) if user.is_dir() else []
    return [p for p in files if p.name == only] if only else files


def _in_git(file):
    return subprocess.run(["git", "-C", str(Path(file).parent), "rev-parse", "--git-dir"],
                          capture_output=True).returncode == 0


def extract(hypr, only=None):
    files = _modules(hypr, only)
    if not files:
        return {"binds": [], "sites": [], "kept": [], "remapped": [], "tracked": [], "errors": []}
    try:
        result = subprocess.run(["lua", str(EXTRACTOR), str(hypr)] + ["user." + p.stem for p in files],
                                capture_output=True, text=True, timeout=30)
    except subprocess.TimeoutExpired:
        raise RuntimeError("reading the binds took over 30 seconds, so nothing moved")
    if result.returncode != 0:
        raise RuntimeError(result.stderr.strip() or "hypr_binds.lua failed")
    found = json.loads(result.stdout)
    allowed = {str(p.resolve()) for p in files}
    adopted = {str(p.resolve()) for p in files if ADOPTED.fullmatch(p.name)}
    texts = {}

    def span(file, line, call):
        if file not in allowed:
            return None, ("shared", "")
        if file not in texts:
            text = Path(file).read_text()
            texts[file] = (text, code_only(text))
        return statement_span(*texts[file], line, call)

    # Group by call site: one hl.bind in a loop makes several binds
    sites = {}
    for entry in found["binds"]:
        file = str(Path(entry["file"]).resolve()) if entry["file"] else ""
        sites.setdefault((file, entry["line"]), []).append(entry)

    binds, moved_sites, kept, remapped = [], [], [], []
    # The keys whose binds moved, as written (EXAMPLE_KEYS may move one)
    moved_keys = set()
    for (file, line), entries in sorted(sites.items(), key=lambda s: (s[0][0], s[0][1])):
        converted = [to_axiom(entry, file in adopted) for entry in entries]
        _, reason = span(file, line, "hl.bind")
        reason = reason or next((r for _, r in converted if r), None)
        if reason:
            kept += [{"file": file, "line": line, "key": e.get("key") or "", "reason": reason[0], "detail": reason[1]}
                     for e in entries]
            continue
        made = [b for b, _ in converted]
        binds += made
        remapped += [{"from": e["key"], "to": b["key"], "action": b["action"]}
                     for e, b in zip(entries, made) if b["key"] != e["key"]]
        moved_keys |= {key_id(e["key"]) for e in entries}
        moved_sites.append({"file": file, "line": line, "binds": made})

    unbind_sites = {}
    for entry in found["unbinds"]:
        file = str(Path(entry["file"]).resolve()) if entry["file"] else ""
        unbind_sites.setdefault((file, entry["line"]), []).append(entry)
    for (file, line), entries in sorted(unbind_sites.items()):
        if all(e.get("key") and key_id(e["key"]) in moved_keys for e in entries):
            _, reason = span(file, line, "hl.unbind")
            if not reason:
                moved_sites.append({"file": file, "line": line, "binds": []})

    read = sorted({s["file"] for s in moved_sites} | {k["file"] for k in kept if k["file"] in allowed})
    return {"binds": binds, "sites": moved_sites, "kept": kept, "remapped": remapped,
            "tracked": [f for f in read if _in_git(f)], "errors": found["errors"]}


def remove(hypr, sites):
    allowed = {str(p.resolve()) for p in _modules(hypr)}
    by_file = {}
    for site in sites:
        by_file.setdefault(str(Path(site["file"]).resolve()), []).append(int(site["line"]))
    removed, changed, failed = 0, [], []
    stamp = time.strftime("%Y%m%d-%H%M%S")
    for file, lines in sorted(by_file.items()):
        if file not in allowed:
            failed.append({"file": file, "line": 0, "reason": "notUser", "detail": ""})
            continue
        text = Path(file).read_text()
        code = code_only(text)
        spans = []
        for line in sorted(set(lines)):
            found = None
            for call in ("hl.bind", "hl.unbind"):
                found, _ = statement_span(text, code, line, call)
                if found:
                    break
            if found:
                spans.append(found)
            else:
                failed.append({"file": file, "line": line, "reason": "changed", "detail": ""})
        if not spans:
            continue
        new = text
        for start, end in sorted(spans, reverse=True):
            new = new[:start] + new[end:]
        check = subprocess.run(["luac", "-p", "-"], input=new, capture_output=True, text=True)
        if check.returncode != 0:
            # The file is left alone: every call in it stays, found or not
            failed = [f for f in failed if f["file"] != file]
            failed.append({"file": file, "line": 0, "reason": "syntax", "detail": check.stderr.strip()})
            continue
        shutil.copy2(file, f"{file}.axiom-backup-{stamp}")
        tmp = Path(file + ".axiom-tmp")
        tmp.write_text(new)
        shutil.copymode(file, tmp)
        tmp.replace(file)
        removed += len(spans)
        changed.append(file)
    return {"removed": removed, "files": changed, "failed": failed}


def main():
    args = sys.argv[1:]
    only = None
    if args[:1] == ["extract"] and "--only" in args[2:-1]:
        i = args.index("--only")
        only = args[i + 1]
        del args[i:i + 2]
    if args[:1] not in (["extract"], ["remove"]) or len(args) != (2 if args[0] == "extract" else 3):
        print(__doc__, file=sys.stderr)
        return 2
    hypr = Path(args[1]).expanduser()
    try:
        if args[0] == "extract":
            print(json.dumps(extract(hypr, only)))
        else:
            print(json.dumps(remove(hypr, json.loads(args[2]))))
    except RuntimeError as error:
        print(error, file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
