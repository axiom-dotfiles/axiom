pragma ComponentBehavior: Bound
import QtQuick
import qs.services
import qs.components.views.layouts

// The layouts editor: always the last page (pinned by OverlayPages; not
// part of config). The overlay pages, edge menus and the lock screen on
// the left; the selected one's modules on a canvas (drag to move, drag a
// corner to resize) above the selected module's options, or the library
// to add from. Edits go through OverlayManager's, EdgeMenuManager's and
// LockManager's drafts until saved; a menu's show live on screen.
BaseView {
  id: root

  // What's being edited (OverlayManager.editTarget), as the canvas shows it
  readonly property EditTarget target: OverlayManager.editTarget === "menu" ? menuTarget : OverlayManager.editTarget === "lockscreen" ? lockscreenTarget : pageTarget

  PageTarget {
    id: pageTarget
  }
  MenuTarget {
    id: menuTarget
  }
  LockscreenTarget {
    id: lockscreenTarget
  }

  Component.onCompleted: {
    OverlayManager.ensureLoaded();
    EdgeMenuManager.ensureLoaded();
    LockManager.ensureLoaded();
  }
  // The page unloads when the overlay closes (or it pages two away)
  Component.onDestruction: EdgeMenuManager.stopPreviewing()

  LayoutsEditorLayout {
    id: layout
    grid: root.grid
    editor: root.target.editor
    canvas.modules: root.target.modules
    canvas.icon: root.target.icon
    canvas.title: root.target.title
    canvas.emptyText: root.target.emptyText
    canvas.edge: root.target.edge
    canvas.screenBox: root.target.screenBox
    canvas.screenSize: root.target.screenSize
    canvas.reservedDepth: root.target.reservedDepth
    canvas.reservedLabel: root.target.reservedLabel
    canvas.ghosts: root.target.ghosts
    canvas.fitText: root.target.fitText
    canvas.fitWarning: root.target.fitWarning
    canvas.nudgeText: root.target.nudgeText
    canvas.nudgeVertical: root.target.nudgeVertical
    canvas.canNudgeBack: root.target.canNudgeBack
    canvas.canNudgeForward: root.target.canNudgeForward
    canvas.canCentre: root.target.canCentre
    canvas.nudge: root.target.nudge
    canvas.centre: root.target.centre
    canvas.gridOffset: root.target.gridOffset
    canvas.gridOffsetLimit: root.target.gridOffsetLimit
    canvas.setGridOffset: root.target.setGridOffset
    canvas.latticeSpan: root.target.latticeSpan
    canvas.dirty: OverlayManager.isDirty || EdgeMenuManager.isDirty || LockManager.isDirty
    canvas.canSave: OverlayManager.problems.length === 0 && EdgeMenuManager.problems.length === 0 && LockManager.problems.length === 0
    inspector.editable: root.target.editable
    inspector.notEditableHint: root.target.notEditableHint
    onSave: {
      if (OverlayManager.isDirty)
        OverlayManager.saveChanges();
      if (EdgeMenuManager.isDirty)
        EdgeMenuManager.saveChanges();
      if (LockManager.isDirty)
        LockManager.saveChanges();
    }
    onReset: {
      OverlayManager.resetChanges();
      EdgeMenuManager.resetChanges();
      LockManager.resetChanges();
    }

    LayoutsPanel {
      view: OverlayManager.editTarget === "page" ? pageTarget.view : null
      menu: OverlayManager.editTarget === "menu" ? menuTarget.menu : null
      lockscreen: OverlayManager.editTarget === "lockscreen" ? lockscreenTarget.layout : null
      width: layout.sideWidth
      height: layout.pageHeight
      dragLayer: layout
    }
  }
}
