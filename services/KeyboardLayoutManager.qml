pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland

// Active xkb layout of the main keyboard, shared by every KeyboardLayout
// widget. Read from `hyprctl devices` once, then again whenever Hyprland
// reports a layout switch or a config reload (no polling).
QtObject {
  id: root

  property var layouts: []
  property int layoutIndex: 0
  property string keymapName: ""

  function refresh() {
    _devices.running = true;
  }

  // "next" or "prev", on every keyboard
  function cycle(direction) {
    Quickshell.execDetached(["hyprctl", "switchxkblayout", "all", direction]);
  }

  property Process _devices: Process {
    running: true
    command: ["hyprctl", "devices", "-j"]
    stdout: StdioCollector {
      onStreamFinished: {
        try {
          const keyboards = JSON.parse(text).keyboards || [];
          const main = keyboards.find(k => k.main) ?? keyboards[0];
          if (!main)
            return;
          root.layouts = main.layout.split(",").map(l => l.trim());
          root.layoutIndex = main.active_layout_index ?? 0;
          root.keymapName = main.active_keymap ?? "";
        } catch (e) {
          console.warn("[KeyboardLayoutManager] Couldn't read hyprctl devices:", e);
        }
      }
    }
  }

  property Connections _events: Connections {
    target: Hyprland
    function onRawEvent(event) {
      if (event.name === "activelayout" || event.name === "configreloaded")
        Qt.callLater(root.refresh);
    }
  }
}
