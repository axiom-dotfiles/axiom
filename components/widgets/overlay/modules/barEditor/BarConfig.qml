pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import qs.config
import qs.services
import qs.components.widgets.common
import qs.components.widgets.overlay.modules.settings

Rectangle {
  required property var barConfigs
  required property var screen

  id: root
  color: Theme.background
  radius: Menu.cardBorderRadius
  anchors.fill: parent
  border.color: Theme.border
  border.width: Menu.cardBorderWidth
}
