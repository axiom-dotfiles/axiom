#!/usr/bin/env python3
"""Asks the desktop's file picker for a JSON file and prints its path.

Usage: pick_file.py TITLE [FOLDER]

The picker is xdg-desktop-portal's (the GTK or KDE one, whichever the portal
uses), through python-gobject; without either, zenity or kdialog. Exits 1
when the picker is cancelled, 2 when none could be shown.
"""
import os
import shutil
import subprocess
import sys
from urllib.parse import unquote, urlparse


def portal(title, folder):
    import gi

    gi.require_version("Gio", "2.0")
    from gi.repository import Gio, GLib

    bus = Gio.bus_get_sync(Gio.BusType.SESSION)
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

    # Subscribed before the call, so a quick answer isn't missed
    bus.signal_subscribe(
        "org.freedesktop.portal.Desktop",
        "org.freedesktop.portal.Request",
        "Response",
        request,
        None,
        Gio.DBusSignalFlags.NONE,
        on_response,
    )
    options = {
        "handle_token": GLib.Variant("s", token),
        "modal": GLib.Variant("b", True),
        "filters": GLib.Variant("a(sa(us))", [("JSON", [(0, "*.json")])]),
        "current_folder": GLib.Variant("ay", folder.encode() + b"\0"),
    }
    bus.call_sync(
        "org.freedesktop.portal.Desktop",
        "/org/freedesktop/portal/desktop",
        "org.freedesktop.portal.FileChooser",
        "OpenFile",
        GLib.Variant("(ssa{sv})", ("", title, options)),
        None,
        Gio.DBusCallFlags.NONE,
        -1,
        None,
    )
    loop.run()
    if result["code"] != 0 or not result["uris"]:
        return None
    return unquote(urlparse(result["uris"][0]).path)


def fallback(title, folder):
    if shutil.which("zenity"):
        command = ["zenity", "--file-selection", "--title", title, "--filename", folder + "/", "--file-filter", "JSON | *.json"]
    elif shutil.which("kdialog"):
        command = ["kdialog", "--title", title, "--getopenfilename", folder, "*.json"]
    else:
        print("No file picker: install xdg-desktop-portal with python-gobject, zenity or kdialog", file=sys.stderr)
        sys.exit(2)
    done = subprocess.run(command, stdout=subprocess.PIPE, text=True)
    return done.stdout.strip() if done.returncode == 0 else None


def main():
    title = sys.argv[1] if len(sys.argv) > 1 else "Open"
    folder = sys.argv[2] if len(sys.argv) > 2 else os.path.expanduser("~")
    try:
        chosen = portal(title, folder)
    except Exception as error:  # no python-gobject, no portal, or no FileChooser backend
        print(f"Portal file picker unavailable ({error}), trying zenity/kdialog", file=sys.stderr)
        chosen = fallback(title, folder)
    if not chosen:
        sys.exit(1)
    print(chosen)


if __name__ == "__main__":
    main()
