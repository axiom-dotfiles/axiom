pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import qs.config
import qs.components.reusable

// i18n: keys from the schema (module labels)
// A module type in the library: its icon, name and the shapes it fits.
// Dragging it carries a new module at its default size; a click is
// `clicked`.
DragChip {
  id: root

  required property var typeInfo

  icon: root.typeInfo.icon
  label: I18n.tr(root.typeInfo.label)
  readonly property var size: OverlayConfig.defaultSize(root.typeInfo.type)
  payload: ({
      "kind": "module-add",
      "type": root.typeInfo.type,
      "w": root.size[0],
      "h": root.size[1],
      "icon": root.typeInfo.icon,
      "label": I18n.tr(root.typeInfo.label)
    })

  // The shapes it fits, drawn: square, wide, tall
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
