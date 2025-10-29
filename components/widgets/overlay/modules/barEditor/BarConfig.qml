pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import qs.config
import qs.services
import qs.components.widgets.common
import qs.components.widgets.overlay.modules.settings

Rectangle {
  id: root
  required property var barConfigs
  required property var screen
  color: Theme.background
  radius: Menu.cardBorderRadius
  anchors.fill: parent
  border.color: Theme.border
  border.width: Menu.cardBorderWidth

  ColumnLayout {
    id: rowLayout
    anchors.top: parent.top
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.margins: Widget.padding

    Repeater {
      model: BarManager.fullConfig
      SingleBar {
        required property var modelData
        localConfig: modelData
        expanded: modelData.primary
      }
    }
  }
}
