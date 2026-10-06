pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts

import qs.config
import qs.components.reusable

// A notification's action buttons (all but the default one) as pills,
// scrolling sideways when they don't fit; emits invoked after running one
Flickable {
  id: root

  required property var notification

  signal invoked

  readonly property var actions: (notification?.actions ?? []).filter(a => a.identifier !== "default")

  Layout.fillWidth: true
  visible: root.actions.length > 0
  implicitHeight: actionRow.implicitHeight
  contentWidth: actionRow.implicitWidth
  interactive: contentWidth > width
  flickableDirection: Flickable.HorizontalFlick
  clip: true

  RowLayout {
    id: actionRow
    spacing: Widget.spacing / 2

    Repeater {
      model: root.actions

      Rectangle {
        id: pill
        required property var modelData

        implicitWidth: label.implicitWidth + 20
        implicitHeight: label.implicitHeight + 10
        radius: height / 2
        color: area.containsMouse ? Theme.accent : Theme.backgroundHighlight
        scale: area.pressed ? 0.95 : 1

        ColorGlide on color {}
        Glide on scale {}

        StyledText {
          id: label
          anchors.centerIn: parent
          text: pill.modelData.text
          textSize: Appearance.fontSize - 2
          textColor: area.containsMouse ? Theme.background : Theme.foreground
        }

        MouseArea {
          id: area
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: {
            pill.modelData.invoke();
            root.invoked();
          }
        }
      }
    }
  }
}
