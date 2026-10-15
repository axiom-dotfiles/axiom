#!/usr/bin/env python3
"""Asks the desktop's file picker for a file or a folder and prints its path.

Usage: pick_path.py [--folder] [--filter NAME:GLOB] TITLE [START]

--folder picks a folder instead of a file; --filter (files only) offers
only files matching GLOB, under NAME. START is the folder it opens in
(default: home).

The picker is xdg-desktop-portal's (the GTK or KDE one, whichever the portal
uses), through python-gobject; without either, zenity or kdialog. Exits 1
when the picker is cancelled, 2 when none could be shown.
"""
import argparse
import os
import shutil
import subprocess
import sys
from urllib.parse import unquote, urlparse


def parse_args(argv):
    parser = argparse.ArgumentParser(description="Asks the desktop's file picker for a path")
    parser.add_argument("--folder", action="store_true", help="pick a folder instead of a file")
    parser.add_argument("--filter", metavar="NAME:GLOB", help="offer only files matching GLOB")
    parser.add_argument("title", nargs="?", default="Open")
    parser.add_argument("start", nargs="?", default=os.path.expanduser("~"))
    args = parser.parse_args(argv)
    args.filter_name, args.filter_glob = None, None
    if args.filter and not args.folder:
        name, _, glob = args.filter.partition(":")
        args.filter_name, args.filter_glob = (name, glob) if glob else (name, name)
    # A start that's gone (a folder setting not created yet) opens home
    if not os.path.isdir(args.start):
        args.start = os.path.expanduser("~")
    return args


def portal(args):
    import gi

    gi.require_version("Gio", "2.0")
    from gi.repository import Gio, GLib

    bus = Gio.bus_get_sync(Gio.BusType.SESSION)
    if args.folder:
        # A FileChooser before version 3 ignores "directory" and would hand
        # back a file: let zenity/kdialog pick the folder
        (version,) = bus.call_sync(
            "org.freedesktop.portal.Desktop",
            "/org/freedesktop/portal/desktop",
            "org.freedesktop.DBus.Properties",
            "Get",
            GLib.Variant("(ss)", ("org.freedesktop.portal.FileChooser", "version")),
            None,
            Gio.DBusCallFlags.NONE,
            -1,
            None,
        ).unpack()
        if version < 3:
            raise RuntimeError(f"FileChooser version {version} can't pick folders")
    token = f"axiom{os.getpid()}"
    sender = bus.get_unique_name()[1:].replace(".", "_")
    request = f"/org/freedesktop/portal/desktop/request/{sender}/{token}"
    loop = GLib.MainLoop()
    result = {}

    def on_response(_conn, _sender, _path, _iface, _signal, params):
        code, results = params.unpack()
        result["code"] = code
        result["uris"] = results.get("uris", [])
        loop.quit()

    def subscribe(path):
        bus.signal_subscribe(
            "org.freedesktop.portal.Desktop",
            "org.freedesktop.portal.Request",
            "Response",
            path,
            None,
            Gio.DBusSignalFlags.NONE,
            on_response,
        )

    # Subscribed before the call, so a quick answer isn't missed
    subscribe(request)
    options = {
        "handle_token": GLib.Variant("s", token),
        "modal": GLib.Variant("b", True),
        "current_folder": GLib.Variant("ay", args.start.encode() + b"\0"),
    }
    if args.folder:
        # FileChooser version 3+; an older portal shows a file picker
        options["directory"] = GLib.Variant("b", True)
    elif args.filter_glob:
        options["filters"] = GLib.Variant("a(sa(us))", [(args.filter_name, [(0, args.filter_glob)])])
    reply = bus.call_sync(
        "org.freedesktop.portal.Desktop",
        "/org/freedesktop/portal/desktop",
        "org.freedesktop.portal.FileChooser",
        "OpenFile",
        GLib.Variant("(ssa{sv})", ("", args.title, options)),
        None,
        Gio.DBusCallFlags.NONE,
        -1,
        None,
    )
    # A portal older than handle_token answers on a path of its own; without
    # this the picker would wait forever (and the overlay stay hidden)
    (handle,) = reply.unpack()
    if handle != request:
        subscribe(handle)
    loop.run()
    if result["code"] != 0 or not result["uris"]:
        return None
    return unquote(urlparse(result["uris"][0]).path)


# The zenity or kdialog command for args, or None with neither installed
def fallback_command(args):
    if shutil.which("zenity"):
        command = ["zenity", "--file-selection", "--title", args.title, "--filename", args.start + "/"]
        if args.folder:
            command.append("--directory")
        elif args.filter_glob:
            command += ["--file-filter", f"{args.filter_name} | {args.filter_glob}"]
        return command
    if shutil.which("kdialog"):
        if args.folder:
            return ["kdialog", "--title", args.title, "--getexistingdirectory", args.start]
        return ["kdialog", "--title", args.title, "--getopenfilename", args.start] + ([args.filter_glob] if args.filter_glob else [])
    return None


def fallback(args):
    command = fallback_command(args)
    if command is None:
        print("No file picker: install xdg-desktop-portal with python-gobject, zenity or kdialog", file=sys.stderr)
        sys.exit(2)
    done = subprocess.run(command, stdout=subprocess.PIPE, text=True)
    return done.stdout.strip() if done.returncode == 0 else None


def main():
    args = parse_args(sys.argv[1:])
    try:
        chosen = portal(args)
    except Exception as error:  # no python-gobject, no portal, or no FileChooser backend
        print(f"Portal file picker unavailable ({error}), trying zenity/kdialog", file=sys.stderr)
        chosen = fallback(args)
    if not chosen:
        sys.exit(1)
    print(chosen)


if __name__ == "__main__":
    main()
