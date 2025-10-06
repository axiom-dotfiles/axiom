import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.config
import qs.components.widgets.common

Rectangle {
  id: root
  color: Theme.cyan
  anchors.fill: parent
  radius: Menu.cardBorderRadius
  
  // Disk Usage Process
  Process {
    id: diskUsageProcess
    running: true
    command: ["sh", "-c", "df -h / | tail -n1 | awk '{print $5}' | cut -d'%' -f1"]
    
    stdout: SplitParser {
      onRead: data => {
        const usage = parseFloat(data.trim());
        if (!isNaN(usage)) {
          diskUsage = usage;
        }
      }
    }
    
    onRunningChanged: {
      if (!running) {
        timer.setTimeout(() => running = true, 5000);
      }
    }
  }
  
  property real diskUsage: 0
  
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
    
    label: "Storage"
    iconText: ""
    iconColor: Theme.background
    percentage: diskUsage
    temperature: -1  // No temperature for disk
  }
}
