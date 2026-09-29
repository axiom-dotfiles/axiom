pragma ComponentBehavior: Bound
import QtQuick

import qs.services
import qs.config

// A screen recording in progress (ScreenshotManager): a red dot and the
// time recorded; a click stops it. Hidden entirely while not recording.
BarIconWidget {
  id: root

  readonly property bool hidden: !ScreenshotManager.recording
  readonly property int elapsed: ScreenshotManager.recordingElapsed

  icon: "radio_button_checked"
  text: `${Math.floor(root.elapsed / 60)}:${String(root.elapsed % 60).padStart(2, "0")}`
  showIcon: !root.hidden
  showText: !root.hidden && properties.showTimer && ScreenshotManager.recordingSince > 0
  padding: root.hidden ? 0 : root.barConfig.widgetPadding

  backgroundColor: Theme.resolveColor(properties.activeColor)
  opacity: mouseArea.pressed ? 0.8 : 1

  MouseArea {
    id: mouseArea
    anchors.fill: parent
    enabled: !root.hidden
    cursorShape: Qt.PointingHandCursor
    onClicked: ScreenshotManager.stopRecording()
  }
}
