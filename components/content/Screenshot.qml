pragma ComponentBehavior: Bound
import QtQuick
import qs.config
import qs.services
import qs.components.content.parts
import qs.components.reusable
import qs.components.content.base

// Screenshots through ScreenshotManager (region, active window or the
// focused screen), saved to `directory` and copied to the clipboard.
// Recording (ScreenshotManager, with wf-recorder) shows only when it's
// installed.
// properties: { directory }
Card {
  id: root

  readonly property string directory: root.properties.directory || "~/Pictures/Screenshots"
  readonly property bool recording: ScreenshotManager.recording

  readonly property var modes: [["region", "screenshot_region", I18n.tr("Region")], ["window", "wrap_text", I18n.tr("Window")], ["screen", "screenshot_monitor", I18n.tr("Screen")]].concat(ScreenshotManager.hasRecorder || root.recording ? [["record", root.recording ? "stop" : "fiber_manual_record", I18n.tr(root.recording ? "Stop" : "Record")]] : [])

  function capture(mode) {
    if (mode === "record")
      ScreenshotManager.toggleRecording(root.directory);
    else
      ScreenshotManager.take(mode, root.directory);
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
