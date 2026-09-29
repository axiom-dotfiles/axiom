pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland

// Active xkb layout of the main keyboard. Read from `hyprctl devices` once,
// then again whenever Hyprland reports a layout switch (no polling). Left
// click cycles to the next layout, right click to the previous one.
BarIconWidget {
  id: root

  property var layouts: []
  property int layoutIndex: 0
  property string keymapName: ""

  readonly property bool hidden: properties.hideSingle && layouts.length <= 1

  icon: "keyboard"
  text: properties.format === "full" ? keymapName : (layouts[layoutIndex] ?? "").toUpperCase()
  showIcon: !hidden
  showText: !hidden
  padding: hidden ? 0 : root.barConfig.widgetPadding

  opacity: mouseArea.pressed ? 0.8 : 1

  function refresh() {
    devices.running = true;
  }

  Process {
    id: devices
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
          console.warn("[KeyboardLayout] Couldn't read hyprctl devices:", e);
        }
      }
    }
  }

  Connections {
    target: Hyprland
    function onRawEvent(event) {
      if (event.name === "activelayout" || event.name === "configreloaded")
        Qt.callLater(root.refresh);
    }
  }

  MouseArea {
    id: mouseArea
    anchors.fill: parent
    enabled: !root.hidden
    cursorShape: Qt.PointingHandCursor
    acceptedButtons: Qt.LeftButton | Qt.RightButton
    onClicked: mouse => Quickshell.execDetached(["hyprctl", "switchxkblayout", "all", mouse.button === Qt.RightButton ? "prev" : "next"])
  }
}
