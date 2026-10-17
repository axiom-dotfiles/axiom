"""niri's config, read: a KDL parser (the subset of KDL 1 and 2 niri
configs use), its `include`s followed, and its binds as BindKeys' entries.

Not a script of its own: niri_config.py (what NiriConfigWriter asks about
the user's config) and merge_niri_binds.py (the managed takeover's bind
merge) import it, so niri's config is parsed in one place
(docs/dev/compositor/niri-backend.md).

  parse(text)              [Node] (KdlError on a syntax error)
  resolve(main, skip, skip_header)
                           (files, missing, loaded): the config's nodes in
                           the order niri reads them, as (path, [Node])
                           runs (an included file comes where its include
                           was), the includes that were missing, and every
                           file read
  main_config()            the config the running niri ($NIRI_SOCKET) loads
  binds(files)             BindKeys' entries of the binds in effect
"""
import json
import os
import re
import socket
from pathlib import Path


class KdlError(ValueError):
    pass


class Node:
    """A KDL node: its name, arguments, properties, children (None without
    a block) and where it starts (`line`, 1-based; `col` and `start`, a
    character offset into the text)."""

    def __init__(self, name, line, col, start):
        self.name = name
        self.args = []
        self.props = {}
        self.children = None
        self.line = line
        self.col = col
        self.start = start

    def child(self, name):
        return next((c for c in self.children or [] if c.name == name), None)

    def __repr__(self):
        return f"Node({self.name!r}, {self.args!r}, {self.props!r}, {self.children!r})"


# What can't be part of a bare identifier
_NOT_IDENT = set('\\/(){}<>;[]=,"#') | {" ", "\t", "\n", "\r"}
_NUMBER = re.compile(r"[+-]?(0x[0-9a-fA-F_]+|0o[0-7_]+|0b[01_]+|[0-9][0-9_]*(\.[0-9][0-9_]*)?([eE][+-]?[0-9_]+)?)$")
_KEYWORDS = {"true": True, "false": False, "null": None, "#true": True, "#false": False, "#null": None,
             "#inf": float("inf"), "#-inf": float("-inf"), "#nan": float("nan")}
_ESCAPES = {"n": "\n", "r": "\r", "t": "\t", "\\": "\\", "/": "/", '"': '"', "b": "\b", "f": "\f", "s": " "}


class _Parser:
    def __init__(self, text):
        self.text = text
        self.i = 0

    def error(self, message):
        line = self.text.count("\n", 0, self.i) + 1
        raise KdlError(f"line {line}: {message}")

    def peek(self, n=0):
        j = self.i + n
        return self.text[j] if j < len(self.text) else ""

    def at(self, s):
        return self.text.startswith(s, self.i)

    def where(self):
        line = self.text.count("\n", 0, self.i) + 1
        col = self.i - (self.text.rfind("\n", 0, self.i) + 1)
        return line, col, self.i

    def skip_block_comment(self):
        depth = 0
        while self.i < len(self.text):
            if self.at("/*"):
                depth += 1
                self.i += 2
            elif self.at("*/"):
                depth -= 1
                self.i += 2
                if depth == 0:
                    return
            else:
                self.i += 1
        self.error("unterminated /* comment")

    def skip_space(self, newlines):
        """Whitespace and comments, and newlines too when `newlines`; a
        backslash continues a node on the next line."""
        while self.i < len(self.text):
            ch = self.peek()
            if ch in " \t﻿" or (newlines and ch in "\r\n"):
                self.i += 1
            elif self.at("//"):
                while self.i < len(self.text) and self.peek() != "\n":
                    self.i += 1
            elif self.at("/*"):
                self.skip_block_comment()
            elif ch == "\\":
                self.i += 1
                self.skip_space(False)
                if self.peek() == "\r":
                    self.i += 1
                if self.peek() != "\n":
                    self.error("a \\ continues a line only before its end")
                self.i += 1
            else:
                return

    def string(self):
        """A quoted, raw (r"…", r#"…"#, #"…"#) or multi-line string."""
        hashes = 0
        if self.peek() == "r" and self.peek(1) in '"#':
            self.i += 1
            while self.peek() == "#":
                hashes += 1
                self.i += 1
            return self.raw(hashes)
        if self.peek() == "#":
            while self.peek() == "#":
                hashes += 1
                self.i += 1
            return self.raw(hashes)
        if self.at('"""'):
            return self.multiline()
        self.i += 1
        out = []
        while True:
            ch = self.peek()
            if ch == "":
                self.error("unterminated string")
            self.i += 1
            if ch == '"':
                return "".join(out)
            if ch != "\\":
                out.append(ch)
                continue
            esc = self.peek()
            self.i += 1
            if esc == "u":
                match = re.match(r"\{([0-9a-fA-F]{1,6})\}", self.text[self.i:])
                if not match:
                    self.error("bad \\u escape")
                out.append(chr(int(match.group(1), 16)))
                self.i += match.end()
            elif esc in _ESCAPES:
                out.append(_ESCAPES[esc])
            elif esc in " \t\r\n":
                # KDL 2: a backslash eats the whitespace after it
                while self.peek() in " \t\r\n":
                    self.i += 1
            else:
                self.error(f"bad escape \\{esc}")

    def raw(self, hashes):
        multi = self.at('"""')
        quote = '"""' if multi else '"'
        if not self.at(quote):
            self.error("raw string without its quote")
        self.i += len(quote)
        end = self.text.find(quote + "#" * hashes, self.i)
        if end < 0:
            self.error("unterminated raw string")
        value = self.text[self.i:end]
        self.i = end + len(quote) + hashes
        return self._dedent(value) if multi else value

    def multiline(self):
        self.i += 3
        end = self.text.find('"""', self.i)
        if end < 0:
            self.error('unterminated """ string')
        value = self.text[self.i:end]
        self.i = end + 3
        return self._dedent(value)

    @staticmethod
    def _dedent(value):
        lines = value.split("\n")
        if len(lines) < 2:
            return value
        indent = lines[-1]
        return "\n".join(line[len(indent):] if line.startswith(indent) else line.lstrip() for line in lines[1:-1])

    def bare(self):
        start = self.i
        while self.i < len(self.text) and self.peek() not in _NOT_IDENT:
            self.i += 1
        # KDL 2's keywords (#true) and a raw string's hashes start with #
        if self.i == start and self.peek() == "#":
            self.i += 1
            while self.i < len(self.text) and self.peek() not in _NOT_IDENT:
                self.i += 1
        if self.i == start:
            self.error(f"unexpected {self.peek()!r}")
        return self.text[start:self.i]

    def type_annotation(self):
        if self.peek() == "(":
            end = self.text.find(")", self.i)
            if end < 0:
                self.error("unterminated type annotation")
            self.i = end + 1

    def value(self):
        """An argument or property value: (text, value)."""
        self.type_annotation()
        ch = self.peek()
        if ch == '"' or (ch == "r" and self.peek(1) in '"#') or (ch == "#" and self.peek(1) in '"#'):
            return self.string()
        word = self.bare()
        if word in _KEYWORDS:
            return _KEYWORDS[word]
        if _NUMBER.match(word):
            clean = word.replace("_", "")
            try:
                return int(clean, 0) if re.match(r"[+-]?0[xob]|[+-]?[0-9]+$", clean) else float(clean)
            except ValueError:
                self.error(f"bad number {word}")
        return word

    def is_string_start(self):
        ch = self.peek()
        return ch == '"' or (ch == "r" and self.peek(1) in '"#') or (ch == "#" and self.peek(1) in '"#')

    def node(self):
        line, col, start = self.where()
        self.type_annotation()
        name = self.string() if self.is_string_start() else self.bare()
        node = Node(name, line, col, start)
        while True:
            self.skip_space(False)
            ch = self.peek()
            if ch in ("", "\n", "\r", ";", "}"):
                if ch == ";":
                    self.i += 1
                return node
            if ch == "{":
                self.i += 1
                node.children = self.nodes(True)
                return node
            dashed = self.at("/-")
            if dashed:
                self.i += 2
                self.skip_space(False)
                if self.peek() == "{":
                    self.i += 1
                    self.nodes(True)
                    continue
            # An entry: a property (key=value) or an argument
            save = self.i
            key = None
            if self.is_string_start():
                key = self.string()
            elif self.peek() not in "(":
                key = self.bare()
            if key is not None and self.peek() == "=":
                self.i += 1
                value = self.value()
                if not dashed:
                    node.props[key] = value
            else:
                self.i = save
                value = self.value()
                if not dashed:
                    node.args.append(value)

    def nodes(self, in_block):
        found = []
        while True:
            self.skip_space(True)
            while self.peek() == ";":
                self.i += 1
                self.skip_space(True)
            ch = self.peek()
            if ch == "":
                if in_block:
                    self.error("unterminated { block")
                return found
            if ch == "}":
                if not in_block:
                    self.error("unexpected }")
                self.i += 1
                return found
            if self.at("/-"):
                self.i += 2
                self.skip_space(True)
                self.node()
                continue
            found.append(self.node())


def parse(text):
    """The nodes of a KDL document."""
    return _Parser(text).nodes(False)


def config_home():
    return Path(os.environ.get("XDG_CONFIG_HOME") or Path.home() / ".config")


def _niri_pid():
    match = re.search(r"\.(\d+)\.sock$", os.environ.get("NIRI_SOCKET", ""))
    return match.group(1) if match else None


def _proc(pid, name):
    try:
        return (Path("/proc") / pid / name).read_bytes().decode(errors="replace").split("\0")
    except OSError:
        return []


def main_config():
    """The config file of the niri $NIRI_SOCKET names, as it started: its
    -c, else its NIRI_CONFIG, else where niri looks. A config loaded later
    (load-config-file --path: axiom's detached wrapper) doesn't change it."""
    pid = _niri_pid()
    # A NIRI_SOCKET left over from an earlier session can name a pid some
    # other process has since
    if pid and "".join(_proc(pid, "comm")).strip() != "niri":
        pid = None
    if pid:
        args = _proc(pid, "cmdline")
        for i, arg in enumerate(args):
            if arg in ("-c", "--config") and i + 1 < len(args):
                return Path(args[i + 1])
            if arg.startswith("--config="):
                return Path(arg.split("=", 1)[1])
        for entry in _proc(pid, "environ"):
            if entry.startswith("NIRI_CONFIG=") and entry != "NIRI_CONFIG=":
                return Path(entry.split("=", 1)[1])
    elif os.environ.get("NIRI_CONFIG"):
        return Path(os.environ["NIRI_CONFIG"])
    user = config_home() / "niri" / "config.kdl"
    return user if user.is_file() or not Path("/etc/niri/config.kdl").is_file() else Path("/etc/niri/config.kdl")


def resolve(main, skip=(), skip_header=None):
    """The nodes `main` loads in the order niri reads them, as (path,
    nodes) runs with the includes taken out (an included file comes where
    its include was, so later ones win), the include paths that were
    missing, and every file read, in order. Files in `skip` (axiom's own)
    are left out; a file starting with `skip_header` (axiom's managed
    config) gives only what it includes. Each file once."""
    skipped = {Path(p).resolve() for p in skip}
    files, missing, loaded, seen = [], [], [], set()

    def visit(path):
        real = path.resolve()
        if real in seen or real in skipped:
            return
        seen.add(real)
        try:
            text = path.read_text(errors="replace")
        except OSError:
            missing.append(str(path))
            return
        loaded.append(str(path))
        own_skipped = skip_header is not None and text.startswith(skip_header)
        own = []
        for node in parse(text):
            if node.name == "include" and node.args and isinstance(node.args[0], str):
                if own and not own_skipped:
                    files.append((path, own))
                own = []
                target = Path(os.path.expandvars(node.args[0]))
                target = target if target.is_absolute() else path.parent / target
                if target.exists() or node.props.get("optional") is not True:
                    visit(target)
            else:
                own.append(node)
        if own and not own_skipped:
            files.append((path, own))

    visit(Path(main))
    return files, missing, loaded


# --- Binds ---

# niri's modifier names (lower case) as X11 mask bits, and as axiom's
MOD_BITS = {"shift": 1, "ctrl": 4, "control": 4, "alt": 8, "super": 64, "win": 64, "iso_level3_shift": 128,
            "mod5": 128, "iso_level5_shift": 32, "mod3": 32}
MOD_NAMES = {"shift": "SHIFT", "ctrl": "CTRL", "control": "CTRL", "alt": "ALT", "super": "SUPER", "win": "SUPER",
             "iso_level3_shift": "MOD5", "mod5": "MOD5"}
# niri's mouse and wheel keys as axiom's (Hyprland's names)
MOUSE = {"mouseleft": "mouse:272", "mouseright": "mouse:273", "mousemiddle": "mouse:274", "mouseback": "mouse:275",
         "mouseforward": "mouse:276", "wheelscrollup": "mouse_up", "wheelscrolldown": "mouse_down",
         "wheelscrollleft": "mouse_left", "wheelscrollright": "mouse_right"}
AXIOM_MOD_ORDER = ["SUPER", "CTRL", "ALT", "SHIFT", "MOD5"]
# niri's other names for a modifier (lower case), as the one it's compared by
MOD_ALIASES = {"control": "ctrl", "win": "super", "mod5": "iso_level3_shift", "mod3": "iso_level5_shift"}


def running_nested():
    """Whether the niri $NIRI_SOCKET names runs nested, in a window (its
    winit backend, whose only output is "winit")."""
    path = os.environ.get("NIRI_SOCKET", "")
    if not path:
        return False
    try:
        with socket.socket(socket.AF_UNIX) as sock:
            sock.settimeout(2)
            sock.connect(path)
            sock.sendall(b'"Outputs"\n')
            reply = b""
            while not reply.endswith(b"\n"):
                chunk = sock.recv(65536)
                if not chunk:
                    break
                reply += chunk
        outputs = json.loads(reply).get("Ok", {}).get("Outputs", {})
    except (OSError, ValueError, AttributeError):
        return False
    return list(outputs) == ["winit"]


def mod_key(files, nested=False):
    """What `Mod` stands for: input.mod-key (Super by default), or nested
    input.mod-key-nested (Alt by default). axiom never writes Mod."""
    option, name = ("mod-key-nested", "Alt") if nested else ("mod-key", "Super")
    for _, nodes in files:
        for node in nodes:
            if node.name == "input":
                found = node.child(option)
                if found and found.args:
                    name = str(found.args[0])
    return name


def split_combo(combo, mod):
    """A niri key combo ("Mod+Shift+T") as (mods lower case, key), Mod put
    in, or None."""
    parts = [p for p in combo.split("+") if p]
    if not parts:
        return None
    mods = [(mod if p.lower() == "mod" else p).lower() for p in parts[:-1]]
    return mods, parts[-1]


def axiom_key(combo, mod):
    """A niri key combo as axiom writes keys ("SUPER + SHIFT + T"), or None
    when a modifier has no name of axiom's."""
    split = split_combo(combo, mod)
    if not split:
        return None
    mods, key = split
    names = []
    for m in mods:
        if m not in MOD_NAMES:
            return None
        names.append(MOD_NAMES[m])
    names = sorted(set(names), key=AXIOM_MOD_ORDER.index)
    key = MOUSE.get(key.lower(), key.upper() if len(key) == 1 else key)
    return " + ".join(names + [key])


def entry(combo, mod, description):
    """A bind as BindKeys' entry ({ modmask, key, keycode, submap,
    description }), or None when a modifier can't be read."""
    split = split_combo(combo, mod)
    if not split:
        return None
    mask = 0
    for m in split[0]:
        if m not in MOD_BITS:
            return None
        mask |= MOD_BITS[m]
    key = split[1]
    return {"modmask": mask, "key": MOUSE.get(key.lower(), key), "keycode": 0, "submap": "",
            "description": description}


def value_text(value):
    """A value as KDL writes it."""
    if isinstance(value, bool):
        return "true" if value else "false"
    if value is None:
        return "null"
    if isinstance(value, str):
        return '"' + value.replace("\\", "\\\\").replace('"', '\\"').replace("\n", "\\n").replace("\t", "\\t") + '"'
    return str(value)


def node_text(node):
    """A node without children as KDL writes it ("spawn \"foot\"")."""
    return " ".join([node.name] + [value_text(a) for a in node.args] + [f"{k}={value_text(v)}" for k, v in node.props.items()])


def action_text(bind):
    """A bind's action as niri's config writes it, or ""."""
    action = (bind.children or [None])[0]
    return node_text(action) if action is not None else ""


def bind_nodes(files, nested=False):
    """The binds in effect: [(path, node)], a later one on the same key
    (niri compares keys without case, a modifier by any of its names)
    winning."""
    mod = mod_key(files, nested)
    found = {}
    for path, nodes in files:
        for node in nodes:
            if node.name != "binds":
                continue
            for bind in node.children or []:
                split = split_combo(bind.name, mod)
                if split:
                    mods = sorted({MOD_ALIASES.get(m, m) for m in split[0]})
                    found[("+".join(mods), split[1].lower())] = (path, bind)
    return list(found.values()), mod


def binds(files, nested=False):
    """The binds in effect as BindKeys' entries (`nested`: niri runs
    nested, where Mod is its mod-key-nested)."""
    nodes, mod = bind_nodes(files, nested)
    return [e for e in (entry(bind.name, mod, bind.props.get("hotkey-overlay-title") or action_text(bind))
                        for _, bind in nodes) if e]
