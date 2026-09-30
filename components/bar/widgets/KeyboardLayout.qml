pragma ComponentBehavior: Bound
import QtQuick

import qs.services

// Active xkb layout of the main keyboard, from KeyboardLayoutManager. Left
// click cycles to the next layout, right click to the previous one.
BarIconWidget {
  id: root

  readonly property var layouts: KeyboardLayoutManager.layouts
  readonly property int layoutIndex: KeyboardLayoutManager.layoutIndex
  readonly property string keymapName: KeyboardLayoutManager.keymapName

  hidden: properties.hideSingle && layouts.length <= 1

  icon: "keyboard"
  text: properties.format === "full" ? keymapName : (layouts[layoutIndex] ?? "").toUpperCase()

  opacity: mouseArea.pressed ? 0.8 : 1

  MouseArea {
    id: mouseArea
    anchors.fill: parent
    enabled: !root.hidden
    cursorShape: Qt.PointingHandCursor
    acceptedButtons: Qt.LeftButton | Qt.RightButton
    onClicked: mouse => KeyboardLayoutManager.cycle(mouse.button === Qt.RightButton ? "prev" : "next")
  }
}
