pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import qs.config
import qs.components.widgets.overlay.layouts
import qs.components.widgets.overlay.modules

ColumnLayout {
  spacing: Menu.cardSpacing
  Cell2x2 {
    topLeft: Cpu {}
    topRight: Gpu {}
    bottomLeft: Memory {}
    bottomRight: Storage {}
  }

  Cell {
    content: Media {}
  }
}
