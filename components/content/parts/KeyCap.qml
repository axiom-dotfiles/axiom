pragma ComponentBehavior: Bound
import QtQuick
import qs.config
import qs.components.reusable

// One key (or modifier) of a keybind, drawn as a small keycap: its text, or
// an icon before it
Rectangle {
  id: root

  property string text
  property string icon: ""
  // Lower, for the reference's compact density
  property bool compact: false

  implicitHeight: Math.round(Widget.height * (root.compact ? 0.62 : 0.75))
  implicitWidth: Math.max(implicitHeight, content.implicitWidth + Widget.padding)
  radius: Widget.radius / 2
  color: Theme.backgroundHighlight

  Row {
    id: content
    anchors.centerIn: parent
    spacing: Widget.spacing / 2

    StyledIcon {
      visible: root.icon !== ""
      anchors.verticalCenter: parent.verticalCenter
      text: root.icon
      textSize: Appearance.fontSize - (root.compact ? 2 : 1)
    }

    StyledText {
      visible: root.text !== ""
      anchors.verticalCenter: parent.verticalCenter
      text: root.text
      textSize: Appearance.fontSize - (root.compact ? 2 : 1)
    }
  }
}
