pragma ComponentBehavior: Bound
import QtQuick
import qs.config
import qs.services
import qs.components.views.barEditor

// The bar editor page: the bars and the selected one's settings on the
// left; on the right its sections drawn as a strip along the side of the
// page its bar is on (drag widgets within and between them), beside the
// selected widget's options (or the widget library). Edits go through
// BarManager's draft and show live on the running bars, which outline the
// selected widget and report how they fit while the page is on screen.
BaseView {
  id: root

  readonly property string location: barDragLayer.location
  readonly property bool vertical: barDragLayer.vertical
  // The strip's depth across the bar: a vertical one is a column of chips
  readonly property real stripDepth: root.vertical ? root.grid.unit * 0.7 : board.implicitHeight

  // Only the current page is visible; its neighbours are loaded too
  onVisibleChanged: root._watch()
  Component.onCompleted: {
    BarManager.ensureLoaded();
    root._watch();
  }
  Component.onDestruction: BarManager.unwatch(root)

  function _watch() {
    if (root.visible)
      BarManager.watch(root);
    else
      BarManager.unwatch(root);
  }

  BarsPanel {
    implicitWidth: root.sideWidth
    implicitHeight: root.pageHeight
  }

  BarDragLayer {
    id: barDragLayer
    implicitWidth: root.editorWidth
    implicitHeight: root.pageHeight

    SectionsBoard {
      id: board
      x: root.location === "Right" ? barDragLayer.width - width : 0
      y: root.location === "Bottom" ? barDragLayer.height - height : 0
      width: root.vertical ? root.stripDepth : barDragLayer.width
      height: root.vertical ? barDragLayer.height : root.stripDepth
      dragLayer: barDragLayer
    }

    WidgetInspector {
      x: root.location === "Left" ? root.stripDepth + OverlayConfig.cardSpacing : 0
      y: root.location === "Top" ? root.stripDepth + OverlayConfig.cardSpacing : 0
      width: root.vertical ? barDragLayer.width - root.stripDepth - OverlayConfig.cardSpacing : barDragLayer.width
      height: root.vertical ? barDragLayer.height : barDragLayer.height - root.stripDepth - OverlayConfig.cardSpacing
      dragLayer: barDragLayer
    }
  }
}
