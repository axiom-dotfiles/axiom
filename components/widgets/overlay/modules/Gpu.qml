import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io

import qs.config
import qs.components.widgets.common

Rectangle {
  id: root
  color: Theme.blue
  anchors.fill: parent
  radius: Menu.cardBorderRadius
  
  // GPU Usage Process (AMD via rocm-smi)
  Process {
    id: gpuUsageProcess
    running: true
    command: ["sh", "-c", "rocm-smi --showuse --csv 2>&/dev/null | tail -n3 | cut -d',' -f2 | tr -d '%' | sed s/0//"]
    
    stdout: SplitParser {
      onRead: data => {
        const usage = parseFloat(data.trim());
        console.log("GPU Usage Data:", data.trim(), "Parsed:", usage);
        if (!isNaN(usage)) {
          gpuUsage = usage;
        }
      }
    }
    
    onRunningChanged: {
      if (!running) {
        timer.setTimeout(() => running = true, 2000);
      }
    }
  }
  
  // GPU Temperature Process (AMD via rocm-smi)
  Process {
    id: gpuTempProcess
    running: true
    command: ["sh", "-c", "rocm-smi --showtemp --csv 2>/dev/null | tail -n1 | cut -d',' -f2 | tr -d 'c ' || echo '0'"]
    
    stdout: SplitParser {
      onRead: data => {
        const temp = parseFloat(data.trim());
        if (!isNaN(temp)) {
          gpuTemp = temp;
        }
      }
    }
    
    onRunningChanged: {
      if (!running) {
        timer.setTimeout(() => running = true, 2000);
      }
    }
  }
  
  property real gpuUsage: 0
  property real gpuTemp: 0
  
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
    
    label: "GPU"
    iconText: "◆"
    percentage: gpuUsage
    temperature: gpuTemp
  }
}
