pragma ComponentBehavior: Bound
import QtQuick
import qs.config
import qs.services
import qs.components.views.overlayEditor
import qs.components.views.edgeMenuEditor

// The edge menu editor: pinned after the overlay editor (by OverlayPages;
// not part of config). The menus and the selected one's settings on the
// left; its modules drawn on the overlay editor's canvas (drag modules,
// cells and columns around) above what's selected there, or the library.
// Edits go through EdgeMenuManager's draft and show live on the running
// menus; "Show on screen" holds the selected one open while the page is up.
BaseView {
  id: root

  readonly property var menu: EdgeMenuManager.selectedMenu()

  readonly property real pageHeight: root.grid.span(4)
  readonly property real sideWidth: root.grid.unit * 0.8
  // As wide as the page allows, within reason
  readonly property real mainWidth: Math.max(root.grid.unit * 1.8, Math.min(root.grid.unit * 2.8, root.grid.availableWidth - root.sideWidth - OverlayConfig.cardSpacing * 3))
  readonly property real canvasHeight: Math.round((root.pageHeight - OverlayConfig.cardSpacing) * 0.6)

  Component.onCompleted: EdgeMenuManager.ensureLoaded()
  // The page unloads when the overlay closes (or it pages two away)
  Component.onDestruction: EdgeMenuManager.stopPreviewing()

  EditorDragLayer {
    id: dragLayer
    editor: EdgeMenuManager.layout
    implicitWidth: root.sideWidth + OverlayConfig.cardSpacing + root.mainWidth
    implicitHeight: root.pageHeight

    MenusPanel {
      x: 0
      y: 0
      width: root.sideWidth
      height: root.pageHeight
    }

    Item {
      x: root.sideWidth + OverlayConfig.cardSpacing
      y: 0
      width: root.mainWidth
      height: root.canvasHeight

      PageCanvas {
        dragLayer: dragLayer
        editColumns: root.menu ? (root.menu.columns ?? []) : null
        icon: "dock_to_right"
        title: root.menu ? EdgeMenuManager.menuLabel(root.menu, EdgeMenuManager.selectedMenuIndex) : I18n.tr("No edge menus")
        emptyText: I18n.tr("No edge menus yet: add one with New menu.")
      }
    }

    EditorInspector {
      x: root.sideWidth + OverlayConfig.cardSpacing
      y: root.canvasHeight + OverlayConfig.cardSpacing
      width: root.mainWidth
      height: root.pageHeight - root.canvasHeight - OverlayConfig.cardSpacing
      dragLayer: dragLayer
      editable: root.menu !== null
      notEditableHint: I18n.tr("Add a menu to put modules in it")
    }
  }
}
