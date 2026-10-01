pragma ComponentBehavior: Bound
import QtQuick
import qs.config
import qs.components.hosts.overlay

// The layouts editor's page layout: its side panel on the left (this
// item's children, placed by the caller at `sideWidth` × `pageHeight`),
// and on the right the modules being edited drawn on a GridCanvas above
// the EditorInspector. Sized from the page's card grid; the drag layer
// covers all of it.
GridDragLayer {
  id: root

  // The overlay page's card grid (BaseView.grid)
  required property OverlayGrid grid

  // The canvas: the modules to edit (null: nothing to edit), and what it's
  // headed with, or says when there's nothing
  property var editModules: null
  property string canvasTitle: ""
  property string canvasIcon: "dashboard"
  property string emptyText: ""
  property string edge: ""
  // An edge menu's screen around it (GridPlacement.screenBox)
  property var screenBox: null
  property string fitText: ""
  property bool fitWarning: false
  // The inspector: whether modules can be added, and the hint when not
  property bool editable: true
  property string notEditableHint: ""
  // The editor's Save / Reset, on the canvas header
  property bool dirty: false
  property bool canSave: true

  signal save
  signal reset

  readonly property real pageHeight: root.grid.span(8)
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

    GridCanvas {
      dragLayer: root
      modules: root.editModules
      icon: root.canvasIcon
      title: root.canvasTitle
      emptyText: root.emptyText
      edge: root.edge
      screenBox: root.screenBox
      fitText: root.fitText
      fitWarning: root.fitWarning
      dirty: root.dirty
      canSave: root.canSave
      onSave: root.save()
      onReset: root.reset()
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
