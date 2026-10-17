#!/usr/bin/env python3
"""The cursor theme axiom hands XCursor readers (the compositor's
xcursor-theme, XCURSOR_THEME, GTK's cursor-theme), for CursorThemeManager.

Usage: cursor_theme.py <theme> [--size N] [--gsettings]

Many themes name their cursors only the X11 way (left_ptr, hand2,
sb_h_double_arrow) and don't say what they inherit. A lookup by a standard
name ("default", "pointer", "ew-resize": what the cursor-shape protocol and
toolkits ask for) then falls back to the "default" theme, often Adwaita,
before any reader tries the X11 name: the arrow comes from another theme.
For such a theme this writes a companion theme, axiom-cursor-<theme>, in
$XDG_DATA_HOME/icons/: it inherits <theme> and links each standard name
the theme lacks to the theme's own X11 cursor. Each theme's companion has
its own name, so a switch from one to another changes the name readers
get, and they load the cursors again. Prints JSON:

  { "theme": name to use (axiom-cursor-<theme>, or <theme> when it needs
    none or has no XCursor cursors), "filled": how many names were linked }

Companions left from other themes are removed. Nothing is rewritten while
it's already as wanted. --gsettings also sets
org.gnome.desktop.interface cursor-theme (and cursor-size with --size) to
it where gsettings has that schema.
"""
import argparse
import json
import os
import re
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

# What every companion theme's name starts with
NAME = "axiom-cursor"
MARKER = "X-Axiom-Generated=true"

# The standard (CSS / cursor-spec) names and the X11 names themes use for
# them instead, most likely first
ALIASES = {
    "default": ["left_ptr", "arrow", "top_left_arrow", "left_arrow"],
    "pointer": ["hand2", "pointing_hand", "hand1", "hand"],
    "help": ["question_arrow", "whats_this", "left_ptr_help"],
    "progress": ["left_ptr_watch", "half-busy"],
    "wait": ["watch"],
    "text": ["xterm", "ibeam"],
    "crosshair": ["cross", "tcross", "cross_reverse"],
    "cell": ["plus"],
    "alias": ["link", "dnd-link"],
    "copy": ["dnd-copy"],
    "move": ["fleur", "dnd-move", "size_all"],
    "no-drop": ["dnd-no-drop", "circle", "forbidden"],
    "not-allowed": ["crossed_circle", "circle", "forbidden"],
    "grab": ["openhand", "hand1"],
    "grabbing": ["closedhand", "fleur"],
    "all-scroll": ["fleur", "size_all"],
    "col-resize": ["sb_h_double_arrow", "split_h", "size_hor"],
    "row-resize": ["sb_v_double_arrow", "split_v", "size_ver"],
    "n-resize": ["top_side", "size_ver"],
    "e-resize": ["right_side", "size_hor"],
    "s-resize": ["bottom_side", "size_ver"],
    "w-resize": ["left_side", "size_hor"],
    "ne-resize": ["top_right_corner", "size_bdiag"],
    "nw-resize": ["top_left_corner", "size_fdiag"],
    "se-resize": ["bottom_right_corner", "size_fdiag"],
    "sw-resize": ["bottom_left_corner", "size_bdiag"],
    "ew-resize": ["sb_h_double_arrow", "h_double_arrow", "size_hor"],
    "ns-resize": ["sb_v_double_arrow", "v_double_arrow", "size_ver"],
    "nesw-resize": ["fd_double_arrow", "size_bdiag"],
    "nwse-resize": ["bd_double_arrow", "size_fdiag"],
    "zoom-in": ["zoom_in"],
    "zoom-out": ["zoom_out"],
}


def data_home():
    return Path(os.environ.get("XDG_DATA_HOME") or Path.home() / ".local/share")


def search_paths():
    """Where XCursor readers look for themes, as xcursor-rs and libXcursor
    do without XCURSOR_PATH."""
    dirs = [data_home() / "icons", Path.home() / ".icons"]
    data_dirs = os.environ.get("XDG_DATA_DIRS") or "/usr/local/share:/usr/share"
    dirs += [Path(d) / "icons" for d in data_dirs.split(":") if d]
    return dirs + [Path("/usr/share/pixmaps")]


def inherits(index):
    """The themes an index.theme names in its Inherits line."""
    try:
        lines = index.read_text(errors="replace").splitlines()
    except OSError:
        return []
    for line in lines:
        key, _, value = line.partition("=")
        if key.strip() == "Inherits":
            return [t.strip() for t in value.replace(";", ",").split(",") if t.strip()]
    return []


def cursors(theme, walked=None):
    """The cursors `theme` has, its own and what it inherits by name
    (not the implicit "default"): { name: file }, the nearest winning."""
    walked = walked if walked is not None else set()
    if theme in walked or theme.startswith(NAME):
        return {}
    walked.add(theme)
    found, parents = {}, []
    for base in search_paths():
        folder = base / theme
        if not folder.is_dir():
            continue
        if (folder / "cursors").is_dir():
            for entry in sorted((folder / "cursors").iterdir()):
                if entry.exists():
                    found.setdefault(entry.name, str(entry))
        parents += [p for p in inherits(folder / "index.theme") if p not in parents]
    for parent in parents:
        for name, path in cursors(parent, walked).items():
            found.setdefault(name, path)
    return found


def links_for(theme):
    """The standard names `theme` lacks, linked to its X11 cursor:
    { name: file }; None when it has no XCursor cursors at all."""
    have = cursors(theme)
    if not have:
        return None
    links = {}
    for name, aliases in ALIASES.items():
        if name in have:
            continue
        target = next((have[a] for a in aliases if a in have), None)
        if target:
            links[name] = target
    return links


def companion_name(theme):
    """The companion theme's name for `theme`, as a folder and in a
    compositor's config without quoting."""
    return f"{NAME}-{re.sub(r'[^A-Za-z0-9._-]+', '_', theme)}"


def index_text(theme):
    return (f"[Icon Theme]\nName={companion_name(theme)}\nComment={theme}, with the standard cursor names it lacks "
            f"(written by axiom)\nInherits={theme}\n{MARKER}\n")


def current(dest):
    """What `dest` holds now: (index text, { name: link target }), or None."""
    try:
        text = (dest / "index.theme").read_text()
        links = {p.name: os.readlink(p) for p in (dest / "cursors").iterdir() if p.is_symlink()}
    except OSError:
        return None
    return text, links


def ours(dest):
    try:
        return MARKER in (dest / "index.theme").read_text()
    except OSError:
        return False


def write(dest, theme, links):
    """Writes the companion theme at `dest`, built beside it and swapped in."""
    dest.parent.mkdir(parents=True, exist_ok=True)
    staged = Path(tempfile.mkdtemp(prefix=f".{dest.name}.", dir=dest.parent))
    try:
        (staged / "cursors").mkdir()
        for name, target in links.items():
            (staged / "cursors" / name).symlink_to(target)
        (staged / "index.theme").write_text(index_text(theme))
        staged.chmod(0o755)
        old = None
        if dest.exists():
            old = dest.with_name(f".{dest.name}.old")
            shutil.rmtree(old, ignore_errors=True)
            dest.rename(old)
        staged.rename(dest)
        if old:
            shutil.rmtree(old, ignore_errors=True)
    except OSError:
        shutil.rmtree(staged, ignore_errors=True)
        raise


def set_gsettings(theme, size):
    """GTK's cursor settings, where gsettings knows them; only what differs."""
    if not shutil.which("gsettings"):
        return
    schema = "org.gnome.desktop.interface"
    wanted = [("cursor-theme", theme)] + ([("cursor-size", str(size))] if size else [])
    for key, value in wanted:
        got = subprocess.run(["gsettings", "get", schema, key], capture_output=True, text=True)
        if got.returncode != 0:
            return
        if got.stdout.strip().strip("'") != value:
            subprocess.run(["gsettings", "set", schema, key, value], capture_output=True)


def main(argv):
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("theme")
    parser.add_argument("--size", type=int, default=0)
    parser.add_argument("--gsettings", action="store_true")
    args = parser.parse_args(argv)
    if args.theme.startswith(NAME) or "/" in args.theme:
        print(f"not a theme to wrap: {args.theme}", file=sys.stderr)
        return 2
    icons = data_home() / "icons"
    dest = icons / companion_name(args.theme)
    links = links_for(args.theme)
    use = args.theme
    if links:
        if current(dest) != (index_text(args.theme), links):
            if dest.exists() and not ours(dest):
                print(f"{dest} isn't axiom's: left as it is", file=sys.stderr)
                return 1
            write(dest, args.theme, links)
        use = dest.name
    # Other themes' companions (and the one this theme no longer needs)
    for other in icons.glob(f"{NAME}*") if icons.is_dir() else []:
        if other.name != use and ours(other):
            shutil.rmtree(other, ignore_errors=True)
    if args.gsettings:
        set_gsettings(use, args.size)
    print(json.dumps({"theme": use, "filled": len(links or {})}))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
