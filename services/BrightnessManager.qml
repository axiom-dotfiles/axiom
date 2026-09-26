pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io

// Screen brightness per monitor: a laptop panel through its sysfs backlight
// (written with brightnessctl, which goes through logind), an external
// monitor over DDC/CI (ddcutil, VCP 0x10). Monitors are found once at
// startup and again when the screens change; values are read then and when
// the OSD opens (`refresh`), never polled. Writes show at once and are
// coalesced per monitor, so held brightness keys don't queue slow DDC calls.
QtObject {
  id: root

  // { screenName: { kind: "backlight" | "ddc", device, bus, max, value } },
  // value 0-1. Replaced on every change, so bindings on it update.
  property var displays: ({})

  // A monitor's brightness was set through axiom (not found on a refresh)
  signal brightnessChanged(string name)

  readonly property real step: 0.05

  function available(name) {
    return displays[name] !== undefined;
  }

  function valueFor(name) {
    return displays[name]?.value ?? 0;
  }

  function set(name, value) {
    const display = displays[name];
    if (!display)
      return;
    const clamped = Math.max(0, Math.min(1, value));
    _update(name, clamped);
    brightnessChanged(name);
    if (_writing[name])
      _pending[name] = clamped;
    else
      _write(name, clamped);
  }

  function stepBy(name, delta) {
    if (available(name))
      set(name, valueFor(name) + delta);
  }

  // Reads the monitor's current value, for changes made outside axiom
  function refresh(name) {
    const display = displays[name];
    if (!display || _writing[name])
      return;
    if (display.kind === "backlight") {
      const raw = parseInt(FileManager.read(`/sys/class/backlight/${display.device}/brightness`));
      if (isFinite(raw))
        _update(name, raw / display.max);
      return;
    }
    _run(["ddcutil", "--bus", String(display.bus), "getvcp", "10", "--terse"], text => {
      // "VCP 10 C <current> <max>"
      const match = text.match(/VCP 10 C (\d+) (\d+)/);
      if (match && !root._writing[name])
        root._update(name, parseInt(match[1]) / Math.max(1, parseInt(match[2])), parseInt(match[2]));
    });
  }

  function _focused() {
    return Hyprland.focusedMonitor?.name ?? "";
  }

  function _update(name, value, max) {
    const display = displays[name];
    if (!display || (display.value === value && (max === undefined || display.max === max)))
      return;
    const next = Object.assign({}, displays);
    next[name] = Object.assign({}, display, {
      "value": value
    }, max === undefined ? {} : {
      "max": max
    });
    displays = next;
  }

  property var _writing: ({})
  property var _pending: ({})

  function _write(name, value) {
    const display = displays[name];
    _writing[name] = true;
    // A backlight at 0 turns the panel off, so it stops at one step
    const command = display.kind === "backlight" ? ["brightnessctl", "-q", "-d", display.device, "set", String(Math.max(1, Math.round(value * display.max)))] : ["ddcutil", "--bus", String(display.bus), "--noverify", "setvcp", "10", String(Math.round(value * display.max))];
    _run(command, (text, exitCode) => {
      if (exitCode !== 0)
        console.warn(`[BrightnessManager] ${command[0]} failed for ${name} (exit ${exitCode})`);
      const pending = root._pending[name];
      delete root._pending[name];
      root._writing[name] = false;
      if (pending !== undefined && root.displays[name])
        root._write(name, pending);
    });
  }

  // Runs a command once and hands its stdout and exit code to `done`
  function _run(command, done) {
    const process = _oneShot.createObject(root, {
      "command": command
    });
    process.finished.connect((text, exitCode) => {
      done(text, exitCode);
      process.destroy();
    });
    process.running = true;
  }

  property Component _oneShot: Component {
    Process {
      id: process
      signal finished(string text, int exitCode)
      property string _text: ""
      stdout: StdioCollector {
        onStreamFinished: process._text = text
      }
      onExited: exitCode => process.finished(process._text, exitCode)
    }
  }

  // -- Detection --

  function detect() {
    // Backlights as "backlight <name> <type> <brightness> <max>", then
    // ddcutil's display list
    _run(["sh", "-c", "for d in /sys/class/backlight/*; do [ -r \"$d/max_brightness\" ] && echo \"backlight ${d##*/} $(cat \"$d/type\") $(cat \"$d/brightness\") $(cat \"$d/max_brightness\")\"; done; command -v ddcutil >/dev/null && ddcutil detect --terse 2>/dev/null; true"], text => root._parseDetect(text));
  }

  function _parseDetect(text) {
    const found = {};
    // Several backlights can drive one panel: prefer firmware over
    // platform over raw, as systemd-backlight does
    const priority = {
      "firmware": 0,
      "platform": 1,
      "raw": 2
    };
    const backlights = text.split("\n").filter(line => line.startsWith("backlight ")).map(line => line.split(" ")).sort((a, b) => (priority[a[2]] ?? 3) - (priority[b[2]] ?? 3));
    const panel = Quickshell.screens.map(screen => screen.name).find(name => /^(eDP|LVDS|DSI)-/.test(name));
    if (panel && backlights.length > 0) {
      const [, device, , raw, max] = backlights[0];
      found[panel] = {
        "kind": "backlight",
        "device": device,
        "max": Math.max(1, parseInt(max)),
        "value": parseInt(raw) / Math.max(1, parseInt(max))
      };
    }
    // "Display N / I2C bus: /dev/i2c-9 / DRM connector: card1-DP-1"
    for (const block of text.split(/^Display \d+/m).slice(1)) {
      const bus = block.match(/I2C bus:\s*\/dev\/i2c-(\d+)/)?.[1];
      const connector = block.match(/DRM connector:\s*card\d+-(\S+)/)?.[1];
      if (bus !== undefined && connector && !found[connector])
        found[connector] = {
          "kind": "ddc",
          "bus": parseInt(bus),
          "max": 100,
          "value": displays[connector]?.value ?? 0.5
        };
    }
    displays = found;
    console.log("[BrightnessManager] Found", JSON.stringify(found));
    for (const name of Object.keys(found)) {
      if (found[name].kind === "ddc")
        refresh(name);
    }
  }

  // ddcutil needs a moment after a monitor is plugged in
  property Timer _redetect: Timer {
    interval: 2000
    onTriggered: root.detect()
  }

  property Connections _screens: Connections {
    target: Quickshell

    function onScreensChanged() {
      root._redetect.restart();
    }
  }

  Component.onCompleted: detect()

  // Brightness keys (keybind actions brightnessUp, ...), on the focused
  // monitor: the OSD shows the change
  property IpcHandler _ipc: IpcHandler {
    target: "brightness"

    function up(): void {
      root.stepBy(root._focused(), root.step);
    }

    function down(): void {
      root.stepBy(root._focused(), -root.step);
    }

    function set(percent: int): void {
      root.set(root._focused(), percent / 100);
    }
  }
}
