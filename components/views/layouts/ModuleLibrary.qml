pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.config
import qs.components.reusable

// The modules that can be added to the page or menu being edited: drag one
// onto the canvas, or click it to add it at its default size in the first
// free spot
ColumnLayout {
  id: root

  required property var dragLayer

  readonly property var modules: OverlayConfig.modulesFor(root.dragLayer.editor.host)

  spacing: Widget.spacing

  StyledText {
    Layout.fillWidth: true
    elide: Text.ElideRight
    text: I18n.tr("Drag a module onto the canvas, or click one to add it.")
    opacity: 0.6
    textSize: Appearance.fontSize - 2
  }

  ScrollView {
    id: scroll
    Layout.fillWidth: true
    Layout.fillHeight: true
    clip: true
    ScrollBar.horizontal.policy: ScrollBar.AlwaysOff

    TileFlow {
      id: flow
      minTileWidth: Appearance.fontSize * 16
      width: scroll.availableWidth

      Repeater {
        model: root.modules

        ModuleChip {
          required property var modelData
          width: flow.tileWidth
          dragLayer: root.dragLayer
          typeInfo: modelData
          onClicked: root.dragLayer.editor.addModule(modelData.type)
        }
      }
    }
  }
}
