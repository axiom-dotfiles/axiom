pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import qs.config
import qs.components.reusable

// i18n: keys from the schema (module labels)
// A module type in the library: its icon, name and the slot shapes it
// fits. Dragging it carries a new module; a click is `clicked`.
Rectangle {
  id: root

  required property var dragLayer
  required property var typeInfo

  signal clicked

  implicitHeight: Widget.height + Widget.padding / 2
  radius: Widget.radius
  color: area.containsMouse ? Theme.backgroundHighlight : Theme.background
  border.color: area.containsMouse ? Theme.accent : Theme.border
  border.width: 1

  Behavior on color {
    ColorAnimation {
      duration: Appearance.animFast
    }
  }

  RowLayout {
    anchors.fill: parent
    anchors.leftMargin: Widget.padding
    anchors.rightMargin: Widget.padding
    spacing: Widget.spacing

    StyledIcon {
      text: root.typeInfo.icon
      textColor: Theme.accent
      Layout.preferredWidth: Appearance.fontSize * 1.3
    }

    StyledText {
      text: I18n.tr(root.typeInfo.label)
      elide: Text.ElideRight
      Layout.fillWidth: true
    }

    // The slot shapes it fits, drawn: square, wide, tall
    Row {
      spacing: 3
      Layout.alignment: Qt.AlignVCenter

      Repeater {
        model: ["square", "horizontal", "vertical"]

        Rectangle {
          required property string modelData
          y: (12 - height) / 2
          width: modelData === "horizontal" ? 12 : modelData === "vertical" ? 6 : 8
          height: modelData === "vertical" ? 12 : modelData === "horizontal" ? 6 : 8
          radius: 1
          color: root.typeInfo.shapes.includes(modelData) ? Theme.accent : "transparent"
          border.color: Theme.border
          border.width: 1
          opacity: root.typeInfo.shapes.includes(modelData) ? 0.8 : 0.4
        }
      }
    }
  }

  DragArea {
    id: area
    anchors.fill: parent
    dragLayer: root.dragLayer
    payload: ({
        "kind": "module-add",
        "type": root.typeInfo.type,
        "icon": root.typeInfo.icon,
        "label": I18n.tr(root.typeInfo.label)
      })
    onTapped: root.clicked()
  }
}
