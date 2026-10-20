pragma ComponentBehavior: Bound
import QtQuick
import qs.config
import qs.components.reusable

// A folded direction set's keys in one keycap, spaced (H J K L)
Rectangle {
  id: root

  // The keys, in BindRows.directions order
  required property var keys
  property bool compact: false

  implicitHeight: Math.round(Widget.height * (root.compact ? 0.62 : 0.75))
  implicitWidth: Math.max(implicitHeight, content.implicitWidth + Widget.padding)
  radius: Widget.radius / 2
  color: Theme.backgroundHighlight

  Row {
    id: content
    anchors.centerIn: parent
    spacing: Widget.spacing

    Repeater {
      model: root.keys

      delegate: StyledText {
        required property string modelData
        anchors.verticalCenter: parent?.verticalCenter
        text: modelData
        textSize: Appearance.fontSize - (root.compact ? 2 : 1)
      }
    }
  }
}
