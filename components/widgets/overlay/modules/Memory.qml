import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io

import qs.config
import qs.components.widgets.common

Rectangle {
  id: root
  color: Theme.green
  anchors.fill: parent
  radius: Menu.cardBorderRadius
  border.color: Theme.foreground
  border.width: Menu.cardBorderWidth
  
  // Memory Usage Process
  Process {
    id: memUsageProcess
    running: true
    command: ["sh", "-c", "free | grep Mem | awk '{printf \"%.1f\", ($3/$2) * 100.0}'"]
    
    stdout: SplitParser {
      onRead: data => {
        const usage = parseFloat(data.trim());
        if (!isNaN(usage)) {
          memUsage = usage;
        }
      }
    }
    
    onRunningChanged: {
      if (!running) {
        timer.setTimeout(() => running = true, 2000);
      }
    }
  }
  
  // Memory Temperature Process (if available)
  Process {
    id: memTempProcess
    running: true
    command: ["sh", "-c", "sensors | grep -i 'dimm\\|memory' | head -n1 | awk '{print $3}' | grep -o '[0-9.]*' | head -n1"]
    
    stdout: SplitParser {
      onRead: data => {
        const temp = parseFloat(data.trim());
        if (!isNaN(temp)) {
          memTemp = temp;
        }
      }
    }
    
    onRunningChanged: {
      if (!running) {
        timer.setTimeout(() => running = true, 2000);
      }
    }
  }
  
  property real memUsage: 0
  property real memTemp: 0
  
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
    percentage: memUsage
    temperature: memTemp
  }
}

