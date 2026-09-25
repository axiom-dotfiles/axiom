pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import qs.config
import qs.services
import qs.components.reusable
import qs.components.content.base

// i18n: keys from the schema (view labels)
// The selected page as it will look: its columns side by side, each
// flowing its cells, drawn at the scale that fits. Geometry is scaled by
// hand (not Item.scale) so text and controls stay crisp. Gaps between
// the columns take drops that make a new column.
Card {
  id: root

  required property var dragLayer

  readonly property var view: OverlayManager.selectedView()
  readonly property bool isCustom: root.view?.type === "Custom"
  readonly property var columns: root.isCustom ? (root.view.columns ?? []) : []

  readonly property real gapWidth: Math.max(Widget.spacing * 2, 20)
  // The end "add a column" box, and the space between it and the last column
  readonly property real endSpace: Math.max(Widget.spacing * 2, 12)
  readonly property real endWidth: Widget.height * 1.5 + root.endSpace
  readonly property real columnHeader: Widget.height + Widget.spacing
  // Room under every column to drop at its end (see CanvasColumn)
  readonly property real endZone: Widget.height * 1.5

  // Unscaled size of each column as it flows its cells
  readonly property var flows: root.columns.map(col => OverlayConfig.columnFlow(col.cells))
  readonly property real fullWidth: root.flows.reduce((sum, flow) => sum + flow.width, 0)
  readonly property real fullHeight: Math.max(0, ...root.flows.map(flow => flow.height))
  readonly property real availWidth: area.width - root.columns.length * root.gapWidth - root.endWidth
  readonly property real availHeight: area.height - root.columnHeader - root.endZone - Widget.spacing
  readonly property real scaleFactor: root.fullWidth > 0 && root.fullHeight > 0 ? Math.max(0.05, Math.min(1, root.availWidth / root.fullWidth, root.availHeight / root.fullHeight)) : 1

  readonly property int cellCount: root.columns.reduce((sum, col) => sum + (col.cells?.length ?? 0), 0)
  readonly property int moduleCount: root.columns.reduce((sum, col) => sum + (col.cells ?? []).reduce((n, cell) => n + Object.keys(cell.slots ?? {}).length, 0), 0)

  color: Theme.background
  border.color: Theme.border

  ColumnLayout {
    anchors.fill: parent
    anchors.margins: Widget.padding
    spacing: Widget.spacing

    RowLayout {
      Layout.fillWidth: true
      Layout.preferredHeight: Widget.height + Widget.padding
      spacing: Widget.spacing

      StyledIcon {
        text: root.view ? OverlayConfig.viewIcon(root.view.type) : ""
        textColor: Theme.accent
        textSize: Appearance.fontSize + 6
      }

      StyledText {
        text: !root.view ? I18n.tr("No pages") : root.isCustom ? (root.view.name || I18n.tr("Page {0}", OverlayManager.selectedViewIndex + 1)) : I18n.tr(OverlayConfig.viewInfo(root.view.type)?.label ?? root.view.type)
        textSize: Appearance.fontSize + 4
        font.bold: true
        elide: Text.ElideRight
        Layout.maximumWidth: root.width / 3
      }

      StyledText {
        visible: root.isCustom
        text: I18n.tr("{0} columns · {1} cells · {2} modules", root.columns.length, root.cellCount, root.moduleCount)
        opacity: 0.6
        textSize: Appearance.fontSize - 1
      }

      Item {
        Layout.fillWidth: true
      }

      StyledText {
        visible: root.isCustom
        Layout.maximumWidth: root.width / 3
        horizontalAlignment: Text.AlignRight
        elide: Text.ElideRight
        text: I18n.tr("Drag to rearrange · click to edit")
        opacity: 0.5
        textSize: Appearance.fontSize - 2
      }
    }

    Item {
      id: area
      Layout.fillWidth: true
      Layout.fillHeight: true

      // Clicking the background drops the selection
      MouseArea {
        anchors.fill: parent
        onClicked: OverlayManager.clearSelection()
      }

      // A fixed page, or none at all
      Column {
        anchors.centerIn: parent
        width: Math.min(parent.width, Appearance.fontSize * 30)
        spacing: Widget.spacing
        visible: !root.isCustom

        StyledIcon {
          width: parent.width
          horizontalAlignment: Text.AlignHCenter
          text: root.view ? OverlayConfig.viewIcon(root.view.type) : "view_quilt"
          textColor: Theme.accent
          textSize: Appearance.fontSize * 4
          opacity: 0.8
        }
        StyledText {
          width: parent.width
          horizontalAlignment: Text.AlignHCenter
          wrapMode: Text.WordWrap
          text: I18n.tr(root.view ? "A fixed page: it has no layout to edit. Drag it in the page list to reorder it." : "No pages yet: add one with New page.")
          opacity: 0.7
        }
      }

      ColumnGap {
        anchors.fill: parent
        visible: root.isCustom && root.columns.length === 0
        dragLayer: root.dragLayer
        index: 0
        wide: true
      }

      Row {
        anchors.horizontalCenter: parent.horizontalCenter
        height: parent.height
        visible: root.isCustom && root.columns.length > 0

        // Keyed by count: edits update the columns in place
        Repeater {
          model: root.columns.length

          Row {
            id: columnEntry
            required property int index
            height: parent.height

            ColumnGap {
              width: root.gapWidth
              height: parent.height
              dragLayer: root.dragLayer
              index: columnEntry.index
            }

            CanvasColumn {
              height: parent.height
              width: implicitWidth
              dragLayer: root.dragLayer
              column: columnEntry.index
              columnConfig: root.columns[columnEntry.index]
              scaleFactor: root.scaleFactor
              endZone: root.endZone
            }
          }
        }

        ColumnGap {
          width: root.endWidth
          leadingSpace: root.endSpace
          height: parent.height
          dragLayer: root.dragLayer
          index: root.columns.length
          isEnd: true
        }
      }
    }
  }
}
