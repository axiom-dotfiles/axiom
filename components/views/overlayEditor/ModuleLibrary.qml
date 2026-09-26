pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.config
import qs.services
import qs.components.reusable

// What can be added to a page: module types and cell layouts, to drag
// onto the canvas or click. With `shape` set (an empty slot is selected)
// it lists only the modules that fit it, and a click fills that slot;
// otherwise a click adds a new cell after the selected one, or at the end.
ColumnLayout {
  id: root

  required property var dragLayer
  property string shape: ""

  property int tab: 0
  readonly property var modules: root.shape === "" ? OverlayConfig.modulesFor("overlay") : OverlayConfig.modulesFor("overlay").filter(t => t.shapes.includes(root.shape))

  spacing: Widget.spacing

  RowLayout {
    Layout.fillWidth: true
    spacing: Widget.spacing / 2

    Repeater {
      // One tab when filling a slot. Tabs: I18n.tr("Modules") I18n.tr("Cells")
      model: root.shape === "" ? ["Modules", "Cells"] : ["Modules"]

      StyledContainer {
        id: tabButton
        required property int index
        required property string modelData
        readonly property bool active: root.tab === tabButton.index
        Layout.preferredHeight: Widget.height
        Layout.preferredWidth: tabLabel.implicitWidth + Widget.padding * 2
        backgroundColor: tabButton.active ? Theme.accent : (tabArea.containsMouse ? Theme.backgroundHighlight : "transparent")
        borderColor: tabButton.active ? Theme.accent : Theme.border
        borderWidth: 1

        StyledText {
          id: tabLabel
          anchors.centerIn: parent
          text: I18n.tr(tabButton.modelData)
          textColor: tabButton.active ? Theme.background : Theme.foreground
          font.bold: tabButton.active
        }

        MouseArea {
          id: tabArea
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: root.tab = tabButton.index
        }
      }
    }

    StyledText {
      Layout.fillWidth: true
      Layout.leftMargin: Widget.spacing
      elide: Text.ElideRight
      text: root.shape !== "" ? I18n.tr("Modules that fit a {0} slot: click one to fill it, or drag it anywhere.", I18n.tr(root.shape)) : root.tab === 0 ? I18n.tr("Drag a module onto a slot, or between cells for a cell of its own.") : I18n.tr("Drag a layout into a column, or between columns for a new one.")
      opacity: 0.6
      textSize: Appearance.fontSize - 2
    }
  }

  onShapeChanged: root.tab = 0

  ScrollView {
    id: scroll
    Layout.fillWidth: true
    Layout.fillHeight: true
    clip: true
    ScrollBar.horizontal.policy: ScrollBar.AlwaysOff

    Column {
      width: scroll.availableWidth

      Flow {
        id: flow
        readonly property int columns: Math.max(1, Math.floor(width / (Appearance.fontSize * 16)))
        readonly property real tileWidth: (width - spacing * (columns - 1)) / columns

        width: parent.width
        spacing: Widget.spacing
        visible: root.tab === 0

        Repeater {
          model: root.tab === 0 ? root.modules : []

          ModuleChip {
            required property var modelData
            width: flow.tileWidth
            dragLayer: root.dragLayer
            typeInfo: modelData
            onClicked: {
              const sel = OverlayManager.selected;
              if (root.shape !== "" && sel)
                OverlayManager.placeModule(modelData.type, sel.column, sel.cell, sel.slot);
              else
                OverlayManager.appendModule(modelData.type);
            }
          }
        }
      }

      Flow {
        id: layoutFlow
        width: parent.width
        spacing: Widget.spacing
        visible: root.tab === 1

        Repeater {
          model: root.tab === 1 ? Object.keys(OverlayConfig.layouts) : []

          Rectangle {
            id: layoutTile
            required property string modelData
            width: Appearance.fontSize * 7
            // Room for the tallest layout, so the tiles line up
            height: thumb.step * 4 + layoutName.implicitHeight + Widget.padding * 2 + 4
            radius: Appearance.borderRadius
            color: layoutArea.containsMouse ? Theme.backgroundHighlight : Theme.background
            border.color: layoutArea.containsMouse ? Theme.accent : Theme.border
            border.width: 1

            LayoutThumb {
              id: thumb
              anchors.horizontalCenter: parent.horizontalCenter
              y: Widget.padding + (thumb.step * 4 - thumb.height) / 2
              layout: layoutTile.modelData
              step: Appearance.fontSize * 0.9
              slotColor: Theme.backgroundAlt
            }

            StyledText {
              id: layoutName
              anchors.horizontalCenter: parent.horizontalCenter
              anchors.bottom: parent.bottom
              anchors.bottomMargin: Widget.padding / 2
              text: root.dragLayer.layoutLabel(layoutTile.modelData)
              textSize: Appearance.fontSize - 2
            }

            DragArea {
              id: layoutArea
              anchors.fill: parent
              onDragStarted: (x, y) => root.dragLayer.begin({
                  "kind": "cell-add",
                  "layout": layoutTile.modelData,
                  "icon": "view_quilt",
                  "label": root.dragLayer.layoutLabel(layoutTile.modelData)
                }, layoutArea, x, y)
              onDragMoved: (x, y) => root.dragLayer.move(layoutArea, x, y)
              onDropped: root.dragLayer.end()
              onDragCanceled: root.dragLayer.cancel()
              onTapped: OverlayManager.appendCell(layoutTile.modelData)
            }
          }
        }
      }
    }
  }
}
