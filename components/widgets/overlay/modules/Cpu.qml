import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io

import qs.config
import qs.components.widgets.common
import qs.services

Rectangle {
  id: root
  color: Theme.magenta
  anchors.fill: parent
  border.color: Theme.foreground
  border.width: Menu.cardBorderWidth
  radius: Menu.cardBorderRadius
  
  property real cpuUsage: SystemManager.cpuUsage
  property real cpuTemp: SystemManager.cpuTemp

  SystemMonitor {
    anchors.fill: parent
    anchors.margins: Menu.cardPadding
    
    label: "CPU"
    iconText: ""
    iconColor: Theme.background
    percentage: root.cpuUsage
    temperature: root.cpuTemp
  }
}
