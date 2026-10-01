pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import qs.config
import qs.services
import qs.components.reusable

// i18n: keys from the schema (view labels)
// Layouts editor, left: the overlay's pages as the navigator shows them,
// your own pages (duplicate, remove, New page) then the tool pages (only
// hidden, never removed), each group dragged to reorder within itself
// (click to edit)
ColumnLayout {
  id: root

  required property var dragLayer

  readonly property var views: OverlayManager.localViews ?? []
  // Indices into the views, in the navigator's order
  readonly property var dashboards: root.views.map((view, i) => i).filter(i => !OverlayConfig.isTool(root.views[i].type))
  readonly property var tools: root.views.map((view, i) => i).filter(i => OverlayConfig.isTool(root.views[i].type))

  // Moves page `from` to place `to` within `group` (indices into the
  // views), counted as if it were still in place
  function moveWithin(group, from, to) {
    if (group.length === 0)
      return;
    OverlayManager.moveView(from, to < group.length ? group[to] : group[group.length - 1] + 1);
  }

  spacing: Widget.spacing / 2

  StyledText {
    text: I18n.tr("Overlay pages")
    font.bold: true
    textColor: Theme.accent
  }

  EntryListTarget {
    id: pageList
    dragLayer: root.dragLayer
    moveKind: "page-move"
    count: root.dashboards.length
    onDropRequested: (drag, index) => root.moveWithin(root.dashboards, drag.index, index)

    Repeater {
      model: pageList.count

      ListEntryRow {
        id: entry
        required property int index
        readonly property int viewIndex: root.dashboards[entry.index] ?? -1
        readonly property var entryView: root.views[entry.viewIndex] ?? ({})
        readonly property bool carried: root.dragLayer.draggingKind === "page-move" && root.dragLayer.dragging.index === entry.viewIndex

        width: pageList.width
        height: pageList.rowHeight
        y: entry.index * pageList.rowStep
        opacity: entry.carried ? 0.3 : 1
        icon: OverlayConfig.pageIcon(entry.entryView)
        label: OverlayConfig.viewLabel(entry.entryView, entry.viewIndex)
        dimmed: entry.entryView.visible === false
        selected: OverlayManager.editTarget === "page" && OverlayManager.selectedViewIndex === entry.viewIndex
        changed: OverlayManager.viewChanged(entry.viewIndex)
        onClicked: OverlayManager.editPage(entry.viewIndex)
        dragArea.dragLayer: root.dragLayer
        dragArea.payload: ({
            "kind": "page-move",
            "index": entry.viewIndex,
            "icon": entry.icon,
            "label": entry.label
          })

        RowAction {
          row: entry
          iconText: entry.entryView.visible === false ? "visibility_off" : "visibility"
          tooltipText: entry.entryView.visible === false ? I18n.tr("Show in the navigator") : I18n.tr("Hide from the navigator")
          onClicked: OverlayManager.setViewVisible(entry.viewIndex, entry.entryView.visible === false)
        }

        RowAction {
          row: entry
          iconText: "content_copy"
          tooltipText: I18n.tr("Duplicate this page")
          onClicked: OverlayManager.duplicateView(entry.viewIndex)
        }

        RowAction {
          row: entry
          danger: true
          iconText: "close"
          tooltipText: I18n.tr("Remove this page")
          onClicked: OverlayManager.removeView(entry.viewIndex)
        }
      }
    }
  }

  AddEntryButton {
    Layout.topMargin: Widget.spacing / 2
    text: I18n.tr("New page")
    onClicked: OverlayManager.addView()
  }

  StyledText {
    visible: root.tools.length > 0
    Layout.topMargin: Widget.spacing / 2
    text: I18n.tr("Tools")
    textSize: Appearance.fontSize - 2
    opacity: 0.6
  }

  EntryListTarget {
    id: toolList
    dragLayer: root.dragLayer
    moveKind: "tool-move"
    count: root.tools.length
    onDropRequested: (drag, index) => root.moveWithin(root.tools, drag.index, index)

    Repeater {
      model: toolList.count

      ListEntryRow {
        id: tool
        required property int index
        readonly property int viewIndex: root.tools[tool.index] ?? -1
        readonly property var entryView: root.views[tool.viewIndex] ?? ({})
        readonly property bool shown: tool.entryView.visible !== false
        readonly property bool carried: root.dragLayer.draggingKind === "tool-move" && root.dragLayer.dragging.index === tool.viewIndex

        width: toolList.width
        height: toolList.rowHeight
        y: tool.index * toolList.rowStep
        opacity: tool.carried ? 0.3 : 1
        icon: OverlayConfig.viewIcon(tool.entryView.type)
        label: OverlayConfig.viewLabel(tool.entryView, tool.viewIndex)
        dimmed: !tool.shown
        selected: OverlayManager.editTarget === "page" && OverlayManager.selectedViewIndex === tool.viewIndex
        changed: OverlayManager.viewChanged(tool.viewIndex)
        onClicked: OverlayManager.editPage(tool.viewIndex)
        dragArea.dragLayer: root.dragLayer
        dragArea.payload: ({
            "kind": "tool-move",
            "index": tool.viewIndex,
            "icon": tool.icon,
            "label": tool.label
          })

        RowAction {
          row: tool
          lit: tool.shown
          iconText: tool.shown ? "visibility" : "visibility_off"
          tooltipText: tool.shown ? I18n.tr("Hide from the navigator") : I18n.tr("Show in the navigator")
          onClicked: OverlayManager.setViewVisible(tool.viewIndex, !tool.shown)
        }
      }
    }
  }
}
