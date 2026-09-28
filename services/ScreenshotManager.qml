pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io

import qs.config

// Screenshots (the `screenshot` keybind action, IPC `screenshot take <kind>`,
// launcher `/screenshot`, the Screenshot card), taken natively: while
// `picking`, shell/Screenshot shows a frozen frame (ScreencopyView) on each
// screen, where a region is dragged or a window clicked (`region`), or a
// window clicked (`window`), and crops it at the screen's own resolution.
// `screen` captures the focused monitor at once. The picture is saved in
// <Pictures>/Screenshots (or the card's folder), or only to a scratch file
// with `copyOnly`, copied to the clipboard (wl-copy: Quickshell's clipboard
// is text only) and either notified (click opens it) or opened in an
// annotator (satty or swappy). Recording is wf-recorder over a slurp region.
QtObject {
  id: root

  readonly property string _desktopEntry: "axiom-screenshot"
  property string _lastPath: ""

  // The picker is open (or an immediate capture is running)
  property bool picking: false
  // Picking, or waiting for the overlay to close first
  readonly property bool busy: root.picking || root._delay.running
  // { kind, screen: the screen an immediate `screen` capture takes }
  property var request: null
  // Keep nothing on disk, only copy (saved in config/state/screenshot.json)
  property bool copyOnly: false
  // Open the next capture in the annotator (set in the picker)
  property bool annotate: false
  // "satty" | "swappy" | "": what annotating opens
  readonly property string annotator: DependencyManager.found["satty"] ? "satty" : DependencyManager.found["swappy"] ? "swappy" : ""
  readonly property bool hasRecorder: DependencyManager.found["wf-recorder"] === true
  property bool recording: false

  property string _picturesDir: Quickshell.env("HOME") + "/Pictures"
  property string _directory: ""
  readonly property string _scratchDir: (Quickshell.env("XDG_RUNTIME_DIR") || "/tmp") + "/axiom"

  readonly property var _state: StateManager.createStateHandler("screenshot")

  // kind: "region" | "window" | "screen"; directory: where to save it
  // (a leading ~ is home), empty for <Pictures>/Screenshots
  function take(kind, directory) {
    if (root.busy)
      return;
    root._target = null;
    root._start(kind, directory);
  }

  // A region for another feature (the chat): saved to `path` as a PNG,
  // with no clipboard or notification, then callback(ok). Returns false
  // (and never calls back) when a capture is already running.
  function pick(path, callback) {
    if (root.busy)
      return false;
    root._target = {
      "path": path,
      "callback": callback
    };
    Quickshell.execDetached(["mkdir", "-p", path.replace(/\/[^/]*$/, "")]);
    root._start("region", "");
    return true;
  }

  // { path, callback } while pick() runs
  property var _target: null
  readonly property bool forCaller: root._target !== null

  function _start(kind, directory) {
    if (!["region", "window", "screen"].includes(kind)) {
      console.warn(`[ScreenshotManager] Unknown screenshot kind "${kind}" (region, window or screen)`);
      return;
    }
    root._directory = root._expand(directory) || root._picturesDir + "/Screenshots";
    Quickshell.execDetached(["mkdir", "-p", root._directory, root._scratchDir]);
    root.annotate = false;
    // Let an open overlay or launcher go away first, so it isn't in the
    // picture (the launcher closes itself after running a command)
    const covered = ShellManager.surfaceOpen("overlay") || ShellManager.surfaceOpen("launcher");
    ShellManager.closeOverlay();
    root._delay.kind = kind;
    root._delay.interval = covered ? Appearance.animSlow + 150 : 1;
    root._delay.restart();
  }

  function cancel() {
    root.picking = false;
    root.request = null;
    root._delay.stop();
    root._callBack(false);
  }

  function _callBack(ok) {
    const target = root._target;
    root._target = null;
    target?.callback(ok);
  }

  function setCopyOnly(value) {
    root.copyOnly = value;
    root._state.save({
      "copyOnly": value
    });
  }

  // Called by the picker with the cropped capture (a grabToImage result),
  // or null when grabbing failed
  function finish(result) {
    root.picking = false;
    root.request = null;
    root._watchdog.stop();
    if (root._target) {
      root._callBack(!!result && result.saveToFile(root._target.path));
      return;
    }
    const name = Qt.formatDateTime(new Date(), "yyyy-MM-dd_HH-mm-ss") + ".png";
    const path = (root.copyOnly ? root._scratchDir + "/screenshot-" : root._directory + "/") + name;
    if (!result || !result.saveToFile(path)) {
      root.fail(I18n.tr("Couldn't save the picture in {0}.", root.copyOnly ? root._scratchDir : root._directory));
      return;
    }
    root._lastPath = path;
    Quickshell.execDetached(["sh", "-c", 'wl-copy --type image/png < "$1"', "sh", path]);
    if (root.annotate && root.annotator !== "") {
      root.annotate = false;
      Quickshell.execDetached(root.annotator === "satty" ? ["satty", "--filename", path, "--output-filename", path] : ["swappy", "-f", path, "-o", path]);
      return;
    }
    root.annotate = false;
    Quickshell.execDetached(["notify-send", "-a", "axiom", "-i", path, "-h", "string:desktop-entry:" + _desktopEntry, "--", I18n.tr("Screenshot saved"), root.copyOnly ? I18n.tr("Copied to the clipboard.") : I18n.tr("Copied to the clipboard. Click to open it.")]);
  }

  function fail(reason) {
    root.picking = false;
    root.request = null;
    root.annotate = false;
    root._watchdog.stop();
    console.warn("[ScreenshotManager]", reason);
    if (root._target) {
      root._callBack(false);
      return;
    }
    NotificationManager.sendNotification("axiom", I18n.tr("Screenshot failed"), reason);
  }

  // Recording: an area picked with slurp, recorded by wf-recorder until
  // stopRecording(). Kept here, since the card that starts it is gone
  // once the overlay closes.
  function startRecording(directory) {
    if (root.recording || !root.hasRecorder)
      return;
    const dir = root._expand(directory) || root._picturesDir + "/Screenshots";
    ShellManager.closeOverlay();
    root.recording = true;
    // Let the overlay slide away before picking the area
    root._recordDelay.directory = dir;
    root._recordDelay.restart();
  }

  function stopRecording() {
    Quickshell.execDetached(["pkill", "-INT", "-x", "wf-recorder"]);
    // One started before a reload isn't ours to see exit
    if (!root._recorder.running)
      root.recording = false;
  }

  function _expand(directory) {
    return String(directory ?? "").replace(/^~(?=\/|$)/, Quickshell.env("HOME"));
  }

  property Timer _delay: Timer {
    property string kind: ""
    onTriggered: {
      root.request = {
        "kind": kind,
        "screen": Hyprland.focusedMonitor?.name ?? ""
      };
      root.picking = true;
      if (kind === "screen")
        root._watchdog.restart();
    }
  }

  // An immediate capture that never reports back (no frame from the
  // compositor) gives up rather than blocking every later one
  property Timer _watchdog: Timer {
    interval: 3000
    onTriggered: {
      if (root.picking)
        root.fail(I18n.tr("The compositor sent no picture of the screen."));
    }
  }

  property Timer _recordDelay: Timer {
    property string directory: ""
    interval: Appearance.animSlow + 150
    onTriggered: {
      root._recorder.command = ["sh", "-c", 'mkdir -p "$1" && area=$(slurp) && exec wf-recorder -g "$area" -f "$1/Recording_$(date +%Y%m%d_%H%M%S).mp4"', "sh", directory];
      root._recorder.running = true;
    }
  }

  property Process _recorder: Process {
    onExited: root.recording = false
  }

  property Process _probe: Process {
    command: ["sh", "-c", 'xdg-user-dir PICTURES 2>/dev/null; pgrep -x wf-recorder >/dev/null && echo rec; true']
    stdout: StdioCollector {
      onStreamFinished: {
        const lines = text.split("\n").map(line => line.trim()).filter(line => line !== "");
        if (lines[0]?.startsWith("/"))
          root._picturesDir = lines[0];
        // A recording from before a reload: only stopping it is offered
        root.recording = root.recording || lines.includes("rec");
      }
    }
  }

  Component.onCompleted: {
    root.copyOnly = root._state.load({}).copyOnly === true;
    DependencyManager.check(["satty", "swappy", "wf-recorder"]);
    root._probe.running = true;
    NotificationManager.registerHandler(_desktopEntry, () => {
      if (root._lastPath !== "")
        Quickshell.execDetached(["xdg-open", root._lastPath]);
    });
  }

  property IpcHandler _ipc: IpcHandler {
    target: "screenshot"

    function take(kind: string): void {
      root.take(kind, "");
    }

    function cancel(): void {
      root.cancel();
    }
  }
}
