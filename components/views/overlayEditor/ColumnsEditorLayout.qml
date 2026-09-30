pragma ComponentBehavior: Bound
import QtQuick
import qs.config
import qs.components.hosts.overlay

// The page layout the overlay editor and the edge menu editor share: their
// own side panel on the left (this item's children, placed by the caller
// at `sideWidth` × `pageHeight`), and on the right the columns being
// edited drawn on a PageCanvas above the EditorInspector. Sized from the
// page's card grid; the drag layer covers all of it.
EditorDragLayer {
  id: root

  // The overlay page's card grid (BaseView.grid)
  required property OverlayGrid grid

  // The canvas: the columns to edit (null: nothing to edit), and what it's
  // headed with, or says when there's nothing
  property var editColumns: null
  property string canvasTitle: ""
  property string canvasIcon: "view_quilt"
  property string emptyText: ""
  // The inspector: whether modules can be added, and the hint when not
  property bool editable: true
  property string notEditableHint: ""

  readonly property real pageHeight: root.grid.span(4)
  readonly property real sideWidth: root.grid.unit * 0.8
  // As wide as the page allows, within reason
  readonly property real mainWidth: Math.max(root.grid.unit * 1.8, Math.min(root.grid.unit * 2.8, root.grid.availableWidth - root.sideWidth - OverlayConfig.cardSpacing * 3))
  readonly property real canvasHeight: Math.round((root.pageHeight - OverlayConfig.cardSpacing) * 0.6)

  implicitWidth: root.sideWidth + OverlayConfig.cardSpacing + root.mainWidth
  implicitHeight: root.pageHeight

  Item {
    x: root.sideWidth + OverlayConfig.cardSpacing
    y: 0
    width: root.mainWidth
    height: root.canvasHeight

    PageCanvas {
      dragLayer: root
      editColumns: root.editColumns
      icon: root.canvasIcon
      title: root.canvasTitle
      emptyText: root.emptyText
    }
  }

  EditorInspector {
    x: root.sideWidth + OverlayConfig.cardSpacing
    y: root.canvasHeight + OverlayConfig.cardSpacing
    width: root.mainWidth
    height: root.pageHeight - root.canvasHeight - OverlayConfig.cardSpacing
    dragLayer: root
    editable: root.editable
    notEditableHint: root.notEditableHint
  }
}
