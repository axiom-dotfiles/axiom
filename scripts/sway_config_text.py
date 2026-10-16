#!/usr/bin/env python3
"""Prints the sway config in effect as one text, its includes put in.

Usage: sway_config_text.py [--config PATH] [--skip PATH]...

sway's get_config reply holds only the main file, without what it includes;
SwayConfigWriter needs all of it to know which keys the user's config binds.
The main file is --config, else the one the running sway was started with
(-c in the command line of the sway that $SWAYSOCK names), else the first
of the places sway looks. `include` lines are replaced by the files they
name (globs, ~ and $variables set before them; relative to the including
file's folder), each once; --skip leaves files out (axiom's own module).
Exits 1 when no config is found.
"""
import argparse
import glob
import os
import re
import sys


def sway_pid():
    match = re.search(r"sway-ipc\.\d+\.(\d+)\.sock$", os.environ.get("SWAYSOCK", ""))
    return match.group(1) if match else None


def started_with():
    pid = sway_pid()
    if not pid:
        return None
    try:
        with open(f"/proc/{pid}/cmdline", "rb") as f:
            args = f.read().decode(errors="replace").split("\0")
    except OSError:
        return None
    for i, arg in enumerate(args):
        if arg in ("-c", "--config") and i + 1 < len(args):
            return args[i + 1]
        if arg.startswith("--config="):
            return arg.split("=", 1)[1]
    return None


def main_config():
    home = os.path.expanduser("~")
    xdg = os.environ.get("XDG_CONFIG_HOME") or os.path.join(home, ".config")
    places = [started_with(), os.path.join(home, ".sway/config"), os.path.join(xdg, "sway/config"),
              os.path.join(home, ".i3/config"), os.path.join(xdg, "i3/config"), "/etc/sway/config"]
    return next((p for p in places if p and os.path.isfile(p)), None)


def expand(text, variables):
    for name in sorted(variables, key=len, reverse=True):
        text = text.replace(name, variables[name])
    return text


def inline(path, skip, seen, variables):
    real = os.path.realpath(path)
    if real in seen or real in skip:
        return ""
    seen.add(real)
    try:
        with open(path, encoding="utf-8", errors="replace") as f:
            lines = f.read().splitlines()
    except OSError:
        return ""
    out = [f"# axiom: from {path}"]
    for line in lines:
        stripped = line.strip()
        var = re.match(r"set\s+(\$\S+)\s+(.*)$", stripped)
        if var:
            variables[var.group(1)] = expand(var.group(2), variables).strip()
        include = re.match(r"include\s+(.+)$", stripped)
        if not include:
            out.append(line)
            continue
        pattern = os.path.expanduser(expand(include.group(1).strip().strip("\"'"), variables))
        if not os.path.isabs(pattern):
            pattern = os.path.join(os.path.dirname(path), pattern)
        for name in sorted(glob.glob(pattern)):
            if os.path.isfile(name):
                out.append(inline(name, skip, seen, variables))
    return "\n".join(out)


def main(argv):
    parser = argparse.ArgumentParser(description="Prints the sway config with its includes put in")
    parser.add_argument("--config", help="the main config (default: the running sway's)")
    parser.add_argument("--skip", action="append", default=[], help="a file to leave out")
    args = parser.parse_args(argv)
    path = args.config or main_config()
    if not path or not os.path.isfile(path):
        print("sway_config_text.py: no sway config found", file=sys.stderr)
        return 1
    skip = {os.path.realpath(os.path.expanduser(p)) for p in args.skip}
    print(inline(path, skip, set(), {}))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
