pragma ComponentBehavior: Bound
import QtQuick
import qs.config
import qs.services
import qs.components.views.overlayEditor

// The overlay editor: always the last page (pinned by OverlayPages; not
// part of config). The pages on the left; the
// selected page drawn on a canvas (drag modules, cells and columns
// around) above what's selected there, or the library to drag from.
// Edits go through OverlayManager's draft until saved.
// i18n: keys from the schema (view labels)
BaseView {
  id: root

  readonly property var view: OverlayManager.selectedView()
  readonly property bool isCustom: root.view?.type === "Custom"

  Component.onCompleted: OverlayManager.ensureLoaded()

  ColumnsEditorLayout {
    id: layout
    grid: root.grid
    editor: OverlayManager.layout
    onPageMoved: (from, to) => OverlayManager.moveView(from, to)
    editColumns: root.isCustom ? (root.view.columns ?? []) : null
    canvasIcon: root.view ? OverlayConfig.viewIcon(root.view.type) : "view_quilt"
    canvasTitle: !root.view ? I18n.tr("No pages") : root.isCustom ? (root.view.name || I18n.tr("Page {0}", OverlayManager.selectedViewIndex + 1)) : I18n.tr(OverlayConfig.viewInfo(root.view.type)?.label ?? root.view.type)
    emptyText: I18n.tr(root.view ? "A fixed page: it has no layout to edit. Drag it in the page list to reorder it." : "No pages yet: add one with New page.")
    editable: root.isCustom
    notEditableHint: I18n.tr("Pick a custom page to add modules to it")

    PagesPanel {
      width: layout.sideWidth
      height: layout.pageHeight
      dragLayer: layout
    }
  }
}
