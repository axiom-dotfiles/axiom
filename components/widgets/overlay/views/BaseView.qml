pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import qs.config
import qs.components.widgets.overlay.layouts

Item {
  id: overlayColumn
  required property var screen
  default property alias content: rowLayout.data
  
  implicitWidth: rowLayout.implicitWidth
  implicitHeight: rowLayout.implicitHeight
  
  RowLayout {
    id: rowLayout
    spacing: Menu.cardSpacing
  }
}
