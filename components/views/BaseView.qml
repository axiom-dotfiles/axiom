pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import qs.config
import qs.components.hosts.overlay

Item {
  id: root
  // This screen's card grid (OverlayGrid): size cards and panels from it
  property OverlayGrid grid
  // This view's entry in Overlay.views
  property var viewConfig

  // Hand-built pages are two cards tall; one that's a single card is this
  // wide, and an editor's side panel (the lists) is `sideWidth`
  readonly property real pageHeight: root.grid ? root.grid.span(4) : 0
  readonly property real cardPageWidth: root.grid ? root.grid.unit * 2.6 + OverlayConfig.cardSpacing : 0
  readonly property real sideWidth: root.grid ? root.grid.unit * 0.8 : 0
  default property alias content: rowLayout.data

  implicitWidth: rowLayout.implicitWidth
  implicitHeight: rowLayout.implicitHeight

  RowLayout {
    id: rowLayout
    spacing: OverlayConfig.cardSpacing
  }
}
