import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io

import qs.config
import qs.components.widgets.common

Rectangle {
  id: root
  color: Theme.magenta
  anchors.fill: parent
  radius: Menu.cardBorderRadius
  
  // CPU Usage Process
  Process {
    id: cpuUsageProcess
    running: true
    command: ["sh", "-c", "top -bn2 -d 0.5 | grep 'Cpu(s)' | tail -n1 | awk '{print $2}' | cut -d'%' -f1"]
    
    stdout: SplitParser {
      onRead: data => {
        const usage = parseFloat(data.trim());
        if (!isNaN(usage)) {
          cpuUsage = usage;
        }
      }
    }
    
    onRunningChanged: {
      if (!running) {
        timer.setTimeout(() => running = true, 2000);
      }
    }
  }
  
  // CPU Temperature Process
  Process {
    id: cpuTempProcess
    running: true
    command: ["sh", "-c", "sensors | grep -i 'Package id 0\\|Tdie\\|CPU Temperature' | head -n1 | awk '{print $4}' | grep -o '[0-9.]*' | head -n1"]
    
    stdout: SplitParser {
      onRead: data => {
        const temp = parseFloat(data.trim());
        if (!isNaN(temp)) {
          cpuTemp = temp;
        }
      }
    }
    
    onRunningChanged: {
      if (!running) {
        timer.setTimeout(() => running = true, 2000);
      }
    }
  }
  
  property real cpuUsage: 0
  property real cpuTemp: 0
  
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
    
    label: "CPU"
    iconText: ""
    iconColor: Theme.background
    percentage: cpuUsage
    temperature: cpuTemp
  }
}
