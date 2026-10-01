pragma ComponentBehavior: Bound
import QtQuick
import qs.config
import qs.services
import qs.components.views.overlayEditor
import qs.components.views.edgeMenuEditor

// The edge menu editor, the EdgeMenuEditor view type. The menus and the
// selected one's settings on the left; its modules drawn on the overlay
// editor's canvas (drag modules, cells and columns around) above what's
// selected there, or the library.
// Edits go through EdgeMenuManager's draft and show live on the running
// menus; "Show on screen" holds the selected one open while the page is up.
BaseView {
  id: root

  readonly property var menu: EdgeMenuManager.selectedMenu()

  Component.onCompleted: EdgeMenuManager.ensureLoaded()
  // The page unloads when the overlay closes (or it pages two away)
  Component.onDestruction: EdgeMenuManager.stopPreviewing()

  ColumnsEditorLayout {
    id: layout
    grid: root.grid
    editor: EdgeMenuManager.layout
    editColumns: root.menu ? (root.menu.columns ?? []) : null
    canvasIcon: "dock_to_right"
    canvasTitle: root.menu ? EdgeMenuManager.menuLabel(root.menu, EdgeMenuManager.selectedMenuIndex) : I18n.tr("No edge menus")
    emptyText: I18n.tr("No edge menus yet: add one with New menu.")
    editable: root.menu !== null
    notEditableHint: I18n.tr("Add a menu to put modules in it")
    dirty: EdgeMenuManager.isDirty
    canSave: EdgeMenuManager.problems.length === 0
    onSave: EdgeMenuManager.saveChanges()
    onReset: EdgeMenuManager.resetChanges()

    MenusPanel {
      width: layout.sideWidth
      height: layout.pageHeight
    }
  }
}
