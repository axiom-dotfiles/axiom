pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Io
import qs.config
import qs.services
import qs.components.content.parts
import qs.components.reusable
import qs.components.content.base

// Screenshots through ScreenshotManager (region, active window or the
// focused screen), saved to `directory` and copied to the clipboard.
// Recording, with wf-recorder, shows only when it's installed.
// properties: { directory }
Card {
  id: root

  readonly property string directory: root.properties.directory || "~/Pictures/Screenshots"
  property bool hasRecorder: false
  property bool recording: false

  readonly property var modes: [["region", "screenshot_region", I18n.tr("Region")], ["window", "wrap_text", I18n.tr("Window")], ["screen", "screenshot_monitor", I18n.tr("Screen")]].concat(root.hasRecorder ? [["record", root.recording ? "stop" : "fiber_manual_record", I18n.tr(root.recording ? "Stop" : "Record")]] : [])

  function capture(mode) {
    if (mode !== "record") {
      ScreenshotManager.take(mode, root.directory);
      return;
    }
    if (root.recording) {
      Quickshell.execDetached(["pkill", "-INT", "-x", "wf-recorder"]);
      root.recording = false;
      return;
    }
    ShellManager.closeOverlay();
    // Let the overlay slide away before picking the area
    delay.restart();
  }

  Timer {
    id: delay
    interval: Appearance.animSlow + 150
    onTriggered: {
      const dir = root.directory.replace(/^~/, Quickshell.env("HOME"));
      root.recording = true;
      Quickshell.execDetached(["sh", "-c", 'mkdir -p "$1" && wf-recorder -g "$(slurp)" -f "$1/Recording_$(date +%Y%m%d_%H%M%S).mp4"', "sh", dir]);
    }
  }

  Process {
    running: true
    command: ["sh", "-c", "command -v wf-recorder >/dev/null && echo yes; pgrep -x wf-recorder >/dev/null && echo rec; true"]
    stdout: StdioCollector {
      onStreamFinished: {
        root.hasRecorder = text.includes("yes");
        root.recording = text.includes("rec");
      }
    }
  }

  TileGrid {
    id: grid
    anchors.fill: parent
    anchors.margins: root.pad
    count: root.modes.length

    Repeater {
      model: root.modes

      ActionTile {
        required property var modelData
        required property int index
        x: grid.tileX(index)
        y: grid.tileY(index)
        width: grid.tileWidth
        height: grid.tileHeight
        icon: modelData[1]
        label: modelData[2]
        showLabel: !root.compact
        active: modelData[0] === "record" && root.recording
        activeColor: Theme.error
        onClicked: root.capture(modelData[0])
      }
    }
  }
}
