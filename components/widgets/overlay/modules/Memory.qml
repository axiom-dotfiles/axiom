import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io

import qs.config
import qs.services
import qs.components.widgets.common

Rectangle {
  id: root
  color: Theme.green
  anchors.fill: parent
  radius: Menu.cardBorderRadius
  border.color: Theme.foreground
  border.width: Menu.cardBorderWidth
  
  property real memUsage: SystemManager.memUsage
  property real memTemp: SystemManager.memTemp
  
  Timer {
    id: timer
    function setTimeout(callback, delay) {
      timer.interval = delay;
      timer.repeat = false;
      timer.triggered.connect(callback);
      timer.start();
    }
  }
  
  SystemMonitor {
    anchors.fill: parent
    anchors.margins: Menu.cardPadding
    
    label: "Memory"
    iconText: "▦"
    percentage: root.memUsage
    temperature: root.memTemp
  }
}

