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
  default property alias content: rowLayout.data

  implicitWidth: rowLayout.implicitWidth
  implicitHeight: rowLayout.implicitHeight

  RowLayout {
    id: rowLayout
    spacing: OverlayConfig.cardSpacing
  }
}
