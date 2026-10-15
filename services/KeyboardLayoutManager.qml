pragma Singleton
import QtQuick
import Quickshell.Hyprland

// Active xkb layout of the main keyboard, shared by every KeyboardLayout
// widget. Read once (HyprlandManager.withKeyboard), then again whenever
// Hyprland reports a layout switch or a config reload (no polling).
QtObject {
  id: root

  property var layouts: []
  property int layoutIndex: 0
  property string keymapName: ""

  function refresh() {
    HyprlandManager.withKeyboard(keyboard => {
      if (!keyboard)
        return;
      root.layouts = keyboard.layouts;
      root.layoutIndex = keyboard.index;
      root.keymapName = keyboard.keymap;
    });
  }

  // "next" or "prev", on every keyboard
  function cycle(direction) {
    HyprlandManager.cycleKeyboardLayout(direction);
  }

  property Connections _events: Connections {
    target: Hyprland
    function onRawEvent(event) {
      if (event.name === "activelayout" || event.name === "configreloaded")
        Qt.callLater(root.refresh);
    }
  }

  Component.onCompleted: refresh()
}
