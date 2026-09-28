pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

import qs.config

// Screenshots (the `screenshot` keybind action, IPC `screenshot take <kind>`):
// a region picked with slurp, the active window or the focused monitor,
// taken with grim, copied to the clipboard and saved in
// <Pictures>/Screenshots (or the Screenshot card's folder). The
// notification opens the picture.
QtObject {
  id: root

  readonly property string _desktopEntry: "axiom-screenshot"
  property string _lastPath: ""
  property bool _busy: false

  // kind: "region" | "window" | "screen"; directory: where to save it
  // (a leading ~ is home), empty for <Pictures>/Screenshots
  function take(kind, directory) {
    if (_busy)
      return;
    const geometry = {
      "region": "slurp",
      "window": `hyprctl activewindow -j | jq -r '"\\(.at[0]),\\(.at[1]) \\(.size[0])x\\(.size[1])"'`,
      "screen": ""
    }[kind];
    if (geometry === undefined) {
      console.warn(`[ScreenshotManager] Unknown screenshot kind "${kind}" (region, window or screen)`);
      return;
    }
    _busy = true;
    // Let an open overlay or launcher go away first, so it isn't in the
    // picture (the launcher closes itself after running a command)
    const covered = ShellManager.surfaceOpen("overlay") || ShellManager.surfaceOpen("launcher");
    ShellManager.closeOverlay();
    _delay.interval = covered ? Appearance.animSlow + 150 : 1;
    _delay.kind = kind;
    _delay.geometry = geometry;
    _delay.directory = String(directory ?? "").replace(/^~(?=\/|$)/, Quickshell.env("HOME"));
    _delay.restart();
  }

  property Timer _delay: Timer {
    property string kind: ""
    property string geometry: ""
    property string directory: ""
    onTriggered: {
      // $1: how to find the area (empty: the focused monitor), $2: the folder
      const script = `
dir="$2"
[ -n "$dir" ] || dir="$(xdg-user-dir PICTURES 2>/dev/null || echo "$HOME/Pictures")/Screenshots"
mkdir -p "$dir" || { echo failed; exit 0; }
file="$dir/$(date +%Y-%m-%d_%H-%M-%S).png"
if [ -n "$1" ]; then
  area=$(sh -c "$1") && [ -n "$area" ] && [ "$area" != "null,null nullxnull" ] || { echo cancelled; exit 0; }
  grim -g "$area" "$file" || { echo failed; exit 0; }
else
  grim -o "$(hyprctl monitors -j | jq -r '.[] | select(.focused) | .name')" "$file" || { echo failed; exit 0; }
fi
wl-copy --type image/png < "$file"
echo "saved $file"`;
      root._shot.command = ["sh", "-c", script, "sh", geometry, directory];
      root._shot.running = true;
    }
  }

  // The script prints one line: "saved <path>", "cancelled" (no region
  // picked) or "failed" (grim's complaint goes to stderr, then the log)
  property Process _shot: Process {
    stdout: StdioCollector {
      onStreamFinished: root._finished(text.trim())
    }
    stderr: StdioCollector {
      onStreamFinished: {
        if (text.trim() !== "")
          console.warn("[ScreenshotManager]", text.trim());
      }
    }
  }

  function _finished(result) {
    _busy = false;
    if (result === "cancelled")
      return;
    if (!result.startsWith("saved ")) {
      NotificationManager.sendNotification("axiom", I18n.tr("Screenshot failed"), I18n.tr("Needs grim, slurp, jq and wl-clipboard."));
      return;
    }
    _lastPath = result.slice(6);
    Quickshell.execDetached(["notify-send", "-a", "axiom", "-i", _lastPath, "-h", "string:desktop-entry:" + _desktopEntry, "--", I18n.tr("Screenshot saved"), I18n.tr("Copied to the clipboard. Click to open it.")]);
  }

  Component.onCompleted: NotificationManager.registerHandler(_desktopEntry, () => {
    if (root._lastPath !== "")
      Quickshell.execDetached(["xdg-open", root._lastPath]);
  })

  property IpcHandler _ipc: IpcHandler {
    target: "screenshot"

    function take(kind: string): void {
      root.take(kind, "");
    }
  }
}
