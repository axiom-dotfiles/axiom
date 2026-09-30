pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.config

TabButton {
  id: root

  // -- Configurable Appearance --
  property color activeColor: Theme.accent
  property color inactiveColor: Theme.foregroundAlt

  // -- Implementation --
  Layout.fillWidth: true
  Layout.fillHeight: true

  contentItem: StyledText {
    text: root.text
    textSize: Appearance.fontSize - 2
    textColor: root.checked ? root.activeColor : root.inactiveColor
    horizontalAlignment: Text.AlignHCenter
    verticalAlignment: Text.AlignVCenter
    elide: Text.ElideRight
  }

  background: Rectangle {
    color: root.checked ? Theme.backgroundHighlight : "transparent"
    radius: Widget.radius

    Rectangle {
      anchors.bottom: parent.bottom
      anchors.horizontalCenter: parent.horizontalCenter
      width: parent.width * 0.8
      height: 2
      color: root.activeColor
      visible: root.checked
      radius: 1
    }
  }
}
