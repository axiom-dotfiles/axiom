pragma ComponentBehavior: Bound
import QtQuick
import qs.config
import qs.services
import qs.components.views.barEditor

// The bar editor page: the bars and the selected one's settings on the
// left; its sections (drag widgets within and between them) above the
// selected widget's options (or the widget library) on the right. Edits go
// through BarManager's draft and show live on the running bars.
BaseView {
  id: root

  readonly property real pageHeight: root.grid.span(4)
  readonly property real halfHeight: (root.pageHeight - OverlayConfig.cardSpacing) / 2

  Component.onCompleted: BarManager.ensureLoaded()

  BarsPanel {
    implicitWidth: root.grid.unit * 0.8
    implicitHeight: root.pageHeight
  }

  DragLayer {
    id: dragLayer
    implicitWidth: root.grid.unit * 1.8
    implicitHeight: root.pageHeight

    SectionsBoard {
      x: 0
      y: 0
      width: dragLayer.width
      height: root.halfHeight
      dragLayer: dragLayer
    }

    WidgetInspector {
      x: 0
      y: root.halfHeight + OverlayConfig.cardSpacing
      width: dragLayer.width
      height: root.halfHeight
      dragLayer: dragLayer
    }
  }
}
