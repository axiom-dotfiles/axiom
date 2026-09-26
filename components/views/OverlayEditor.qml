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

  readonly property real pageHeight: root.grid.span(4)
  readonly property real sideWidth: root.grid.unit * 0.8
  // As wide as the page allows, within reason
  readonly property real mainWidth: Math.max(root.grid.unit * 1.8, Math.min(root.grid.unit * 2.8, root.grid.availableWidth - root.sideWidth - OverlayConfig.cardSpacing * 3))
  readonly property real canvasHeight: Math.round((root.pageHeight - OverlayConfig.cardSpacing) * 0.6)

  Component.onCompleted: OverlayManager.ensureLoaded()

  EditorDragLayer {
    id: dragLayer
    editor: OverlayManager.layout
    onPageMoved: (from, to) => OverlayManager.moveView(from, to)
    implicitWidth: root.sideWidth + OverlayConfig.cardSpacing + root.mainWidth
    implicitHeight: root.pageHeight

    PagesPanel {
      x: 0
      y: 0
      width: root.sideWidth
      height: root.pageHeight
      dragLayer: dragLayer
    }

    Item {
      x: root.sideWidth + OverlayConfig.cardSpacing
      y: 0
      width: root.mainWidth
      height: root.canvasHeight

      PageCanvas {
        dragLayer: dragLayer
        editColumns: root.isCustom ? (root.view.columns ?? []) : null
        icon: root.view ? OverlayConfig.viewIcon(root.view.type) : "view_quilt"
        title: !root.view ? I18n.tr("No pages") : root.isCustom ? (root.view.name || I18n.tr("Page {0}", OverlayManager.selectedViewIndex + 1)) : I18n.tr(OverlayConfig.viewInfo(root.view.type)?.label ?? root.view.type)
        emptyText: I18n.tr(root.view ? "A fixed page: it has no layout to edit. Drag it in the page list to reorder it." : "No pages yet: add one with New page.")
      }
    }

    EditorInspector {
      x: root.sideWidth + OverlayConfig.cardSpacing
      y: root.canvasHeight + OverlayConfig.cardSpacing
      width: root.mainWidth
      height: root.pageHeight - root.canvasHeight - OverlayConfig.cardSpacing
      dragLayer: dragLayer
      editable: root.isCustom
      notEditableHint: I18n.tr("Pick a custom page to add modules to it")
    }
  }
}
