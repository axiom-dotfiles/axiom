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
// annotator (satty or swappy; its notification also has an "Edit in …"
// button). Recording (IPC `screenRecord`, the
// `screenRecord` bind, launcher `/record`, or R / the Record switch in an
// open picker) picks its area in the same picker (kind `record`) and runs
// wf-recorder on it until stopped.
QtObject {
  id: root

  readonly property string _desktopEntry: "axiom-screenshot"
  property string _lastPath: ""

  // The picker is open (or an immediate capture is running)
  property bool picking: false
  // Picking, or waiting for the launcher to close first
  readonly property bool busy: root.picking || root._delay.running
  // { kind, screen: the screen an immediate `screen` capture takes }
  property var request: null
  // Keep nothing on disk, only copy (saved in config/state/screenshot.json)
  property bool copyOnly: false
  // Open the next capture in the annotator (set in the picker)
  property bool annotate: false
  // "satty" | "swappy" | "": what annotating opens
  readonly property string annotator: DependencyManager.found["satty"] ? "satty" : DependencyManager.found["swappy"] ? "swappy" : ""
  // Its name as shown ("Satty")
  readonly property string annotatorName: root.annotator === "" ? "" : root.annotator[0].toUpperCase() + root.annotator.slice(1)
  readonly property bool hasRecorder: DependencyManager.found["wf-recorder"] === true
  property bool recording: false
  // When the running recording started (ms), 0 when unknown (started
  // before a reload)
  property real recordingSince: 0
  // Seconds recorded so far, ticking only while recording
  property int recordingElapsed: 0
  property string _recordPath: ""

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
    if (!["region", "window", "screen", "record"].includes(kind)) {
      console.warn(`[ScreenshotManager] Unknown screenshot kind "${kind}" (region, window, screen or record)`);
      return;
    }
    root._directory = root._expand(directory) || root._picturesDir + "/Screenshots";
    Quickshell.execDetached(["mkdir", "-p", root._directory, root._scratchDir]);
    root.annotate = false;
    // The screen is taken as it is (an open overlay included), but the
    // launcher closes itself after running a command: let it go first
    root._delay.kind = kind;
    root._delay.interval = ShellManager.surfaceOpen("launcher") ? Appearance.animSlow + 150 : 1;
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
      root.edit(path);
      return;
    }
    root.annotate = false;
    const notice = ["notify-send", "-a", "axiom", "-i", path, "-h", "string:desktop-entry:" + _desktopEntry];
    const text = ["--", I18n.tr("Screenshot saved"), root.copyOnly ? I18n.tr("Copied to the clipboard.") : I18n.tr("Copied to the clipboard. Click to open it.")];
    if (root.annotator === "") {
      Quickshell.execDetached(notice.concat(text));
      return;
    }
    // With an "Edit in …" button: notify-send waits for it and prints the
    // action. Only the latest notification's button stays live.
    root._nextNotice = {
      "path": path,
      "command": notice.concat(["-A", "edit=" + I18n.tr("Edit in {0}", root.annotatorName)], text)
    };
    // The previous one is stopped first; its exit starts this one
    if (root._savedNotice.running)
      root._savedNotice.running = false;
    else
      root._startNotice();
  }

  function _startNotice() {
    const next = root._nextNotice;
    if (!next)
      return;
    root._nextNotice = null;
    root._noticePath = next.path;
    root._savedNotice.command = next.command;
    root._savedNotice.running = true;
  }

  // Opens a picture in the annotator, which saves over it
  function edit(path) {
    if (root.annotator === "")
      return;
    Quickshell.execDetached(root.annotator === "satty" ? ["satty", "--filename", path, "--output-filename", path] : ["swappy", "-f", path, "-o", path]);
  }

  // Switches an open picker between taking a screenshot and recording
  function setRecordMode(on) {
    if (!root.picking || root.forCaller || !root.request || root.request.kind === "screen" || (on && !root.hasRecorder))
      return;
    root.annotate = false;
    root.request = Object.assign({}, root.request, {
      "kind": on ? "record" : "region"
    });
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

  // Recording: an area picked in the picker (kind `record`), recorded by
  // wf-recorder until stopRecording(). Kept here, since the card that
  // starts it is gone once the overlay closes.
  function startRecording(directory) {
    if (root.recording || root.busy || !root.hasRecorder)
      return;
    root._target = null;
    root._start("record", directory);
  }

  function stopRecording() {
    Quickshell.execDetached(["pkill", "-INT", "-x", "wf-recorder"]);
    // One started before a reload isn't ours to see exit
    if (!root._recorder.running)
      root.recording = false;
  }

  function toggleRecording(directory) {
    if (root.recording)
      root.stopRecording();
    else if (root.busy && root.request?.kind === "record")
      root.cancel();
    else
      root.startRecording(directory);
  }

  // Called by the picker with the area to record: global logical pixels,
  // or a whole screen by name
  function record(area, screenName) {
    root.picking = false;
    root.request = null;
    const path = root._directory + "/Recording_" + Qt.formatDateTime(new Date(), "yyyy-MM-dd_HH-mm-ss") + ".mp4";
    const target = screenName ? ["-o", screenName] : ["-g", `${Math.round(area.x)},${Math.round(area.y)} ${Math.round(area.width)}x${Math.round(area.height)}`];
    root._recordPath = path;
    root._recorder.command = ["wf-recorder"].concat(target, ["-f", path]);
    root._recorder.running = true;
    root.recording = true;
    root.recordingSince = Date.now();
    root.recordingElapsed = 0;
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

  property Timer _recordTick: Timer {
    running: root.recording && root.recordingSince > 0
    interval: 1000
    repeat: true
    onTriggered: root.recordingElapsed = Math.floor((Date.now() - root.recordingSince) / 1000)
  }

  property Process _recorder: Process {
    stderr: StdioCollector {
      id: recorderErrors
    }
    onExited: {
      root.recording = false;
      root.recordingSince = 0;
      root.recordingElapsed = 0;
      root._recordCheck.command = ["test", "-s", root._recordPath];
      root._recordCheck.running = true;
    }
  }

  // Whether the recording left a file: saved, else it failed
  property Process _recordCheck: Process {
    onExited: code => {
      const path = root._recordPath;
      if (code !== 0) {
        const reason = recorderErrors.text.trim().split("\n").pop() || I18n.tr("wf-recorder stopped without writing a file.");
        console.warn("[ScreenshotManager] Recording failed:", reason);
        NotificationManager.sendNotification("axiom", I18n.tr("Recording failed"), reason);
        return;
      }
      root._lastPath = path;
      Quickshell.execDetached(["notify-send", "-a", "axiom", "-h", "string:desktop-entry:" + root._desktopEntry, "--", I18n.tr("Recording saved"), I18n.tr("Saved in {0}. Click to open it.", path.replace(/\/[^/]*$/, ""))]);
    }
  }

  // The picture the live "Edit in …" button opens
  property string _noticePath: ""
  // { path, command } waiting for the previous notice to stop
  property var _nextNotice: null

  property Process _savedNotice: Process {
    stdout: StdioCollector {
      onStreamFinished: {
        if (text.trim() === "edit")
          root.edit(root._noticePath);
      }
    }
    onExited: root._startNotice()
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

  property IpcHandler _recordIpc: IpcHandler {
    target: "screenRecord"

    function toggle(): void {
      root.toggleRecording("");
    }

    function enable(): void {
      if (!root.recording)
        root.startRecording("");
    }

    function disable(): void {
      root.stopRecording();
    }

    function status(): bool {
      return root.recording;
    }
  }
}
