pragma ComponentBehavior: Bound
import QtQuick
import qs.config
import qs.components.reusable

// One key (or modifier) of a keybind, drawn as a small keycap
Rectangle {
  id: root

  property string text

  implicitHeight: Math.round(Widget.height * 0.75)
  implicitWidth: Math.max(implicitHeight, label.implicitWidth + Widget.padding)
  radius: Widget.radius / 2
  color: Theme.backgroundHighlight

  StyledText {
    id: label
    anchors.centerIn: parent
    text: root.text
    textSize: Appearance.fontSize - 1
  }
}
