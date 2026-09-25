pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Io
import qs.config
import qs.services
import qs.components.content.parts
import qs.components.reusable
import qs.components.content.base

// Screenshots with grim + slurp: region, active window or whole screen,
// saved to `directory` and copied to the clipboard. The overlay closes
// first so it isn't in the shot. Recording shows only with wf-recorder.
// properties: { directory }
Card {
  id: root

  readonly property string directory: root.properties.directory || "~/Pictures/Screenshots"
  property bool hasRecorder: false
  property bool recording: false
  property string _pending: ""

  readonly property var modes: [["region", "screenshot_region", I18n.tr("Region")], ["window", "wrap_text", I18n.tr("Window")], ["screen", "screenshot_monitor", I18n.tr("Screen")]].concat(root.hasRecorder ? [["record", root.recording ? "stop" : "fiber_manual_record", I18n.tr(root.recording ? "Stop" : "Record")]] : [])

  function capture(mode) {
    if (mode === "record" && root.recording) {
      Quickshell.execDetached(["pkill", "-INT", "-x", "wf-recorder"]);
      root.recording = false;
      return;
    }
    root._pending = mode;
    ShellManager.toggleOverlay();
    // Let the overlay slide away before capturing
    delay.restart();
  }

  Timer {
    id: delay
    interval: Appearance.animSlow + 150
    onTriggered: {
      const dir = root.directory.replace(/^~/, Quickshell.env("HOME"));
      const ext = root._pending === "record" ? "mp4" : "png";
      const file = `${dir}/${root._pending === "record" ? "Recording" : "Screenshot"}_$(date +%Y%m%d_%H%M%S).${ext}`;
      const geometry = {
        "region": `-g "$(slurp)"`,
        "window": `-g "$(hyprctl -j activewindow | jq -r '"\\(.at[0]),\\(.at[1]) \\(.size[0])x\\(.size[1])"')"`,
        "screen": ""
      };
      if (root._pending === "record") {
        root.recording = true;
        Quickshell.execDetached(["sh", "-c", `mkdir -p "${dir}" && wf-recorder -g "$(slurp)" -f "${file}"`]);
      } else {
        shot.command = ["sh", "-c", `mkdir -p "${dir}" && f="${file}" && grim ${geometry[root._pending]} "$f" && wl-copy < "$f" && echo "$f"`];
        shot.running = true;
      }
    }
  }

  Process {
    id: shot
    stdout: StdioCollector {
      onStreamFinished: {
        const file = text.trim();
        if (file)
          NotificationManager.sendNotification(I18n.tr("Screenshot"), I18n.tr("Screenshot saved"), I18n.tr("{0} (copied to clipboard)", file), {});
      }
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
