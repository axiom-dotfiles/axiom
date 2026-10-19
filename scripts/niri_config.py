#!/usr/bin/env python3
"""What the running niri's config holds that axiom needs, as JSON (for
NiriManager and NiriConfigWriter, which parse no KDL themselves).

Usage: niri_config.py <command> [--config PATH] [--skip PATH]... [--skip-header TEXT]

  main       the config file niri loads: { main }
  includes   every file it loads, its includes followed:
             { main, files: [path], missing: [path] }
  binds      the binds in effect, as BindKeys' entries ({ modmask, key,
             keycode, submap, description }), a later one on a key winning
  info       what NiriManager follows: { gaps, struts: { top, right,
             bottom, left }, layouts ("us,de", or ""), modKey (what Mod
             stands for, as axiom names it: "SUPER"), blur: { enabled,
             passes, offset } (niri's blur strength; off with its `off`
             flag) }

The config is --config, else the one the niri $NIRI_SOCKET names started
with (niri_kdl.main_config). --skip leaves files out (axiom's own
module), --skip-header a file's own nodes when it starts with TEXT (axiom's
managed config: only what it includes is the user's).
Exits 1 when the config can't be read or parsed (the reason on stderr).
"""
import argparse
import json
import sys

import niri_kdl


def info(files):
    gaps, struts, layouts = 16, {"top": 0, "right": 0, "bottom": 0, "left": 0}, ""
    blur = {"enabled": True, "passes": 3, "offset": 3}
    for _, nodes in files:
        for node in nodes:
            if node.name == "blur":
                if node.child("off"):
                    blur["enabled"] = False
                for key in ("passes", "offset"):
                    found = node.child(key)
                    if found and found.args:
                        blur[key] = found.args[0]
            elif node.name == "layout":
                found = node.child("gaps")
                if found and found.args:
                    gaps = found.args[0]
                for side in struts:
                    strut = (node.child("struts") or niri_kdl.Node("", 0, 0, 0)).child(side)
                    if strut and strut.args:
                        struts[side] = strut.args[0]
            elif node.name == "input":
                xkb = ((node.child("keyboard") or niri_kdl.Node("", 0, 0, 0)).child("xkb"))
                layout = xkb.child("layout") if xkb else None
                if layout and layout.args:
                    layouts = str(layout.args[0])
    mod = niri_kdl.mod_key(files, niri_kdl.running_nested())
    return {"gaps": gaps, "struts": struts, "layouts": layouts, "blur": blur,
            "modKey": niri_kdl.MOD_NAMES.get(mod.lower(), mod.upper())}


def main(argv):
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("command", choices=["main", "includes", "binds", "info"])
    parser.add_argument("--config")
    parser.add_argument("--skip", action="append", default=[])
    parser.add_argument("--skip-header")
    args = parser.parse_args(argv)
    main_path = args.config or str(niri_kdl.main_config())
    if args.command == "main":
        print(json.dumps({"main": main_path}))
        return 0
    try:
        files, missing, loaded = niri_kdl.resolve(main_path, args.skip, args.skip_header)
    except niri_kdl.KdlError as error:
        print(f"{main_path}: {error}", file=sys.stderr)
        return 1
    if not loaded:
        print(f"{main_path}: not found", file=sys.stderr)
        return 1
    if args.command == "includes":
        print(json.dumps({"main": main_path, "files": loaded, "missing": missing}))
    elif args.command == "binds":
        print(json.dumps(niri_kdl.binds(files, niri_kdl.running_nested())))
    else:
        print(json.dumps(info(files)))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
