import QtQuick
import Quickshell
import Quickshell.Io

import qs.services
import qs.components.widgets.reusable

IconTextWidget {
  id: root

  property bool isCharging: false
  property bool isDischarging: false
  property int percentage: 0
  property string timeRemaining: ""
  property string warningLevel: "none"

  icon: getBatteryIcon()
  text: `${percentage}%`

  backgroundColor: getBatteryColor()

  iconScale: 1.1
  textScale: 0.9

  function getBatteryIcon() {
    if (isCharging) {
      if (percentage >= 90) return "󰂅";
      if (percentage >= 80) return "󰂋";
      if (percentage >= 60) return "󰂊";
      if (percentage >= 40) return "󰢞";
      if (percentage >= 20) return "󰢝";
      return "󰢜";
    } else {
      if (percentage >= 90) return "󰁹";
      if (percentage >= 80) return "󰂂";
      if (percentage >= 70) return "󰂁";
      if (percentage >= 60) return "󰂀";
      if (percentage >= 50) return "󰁿";
      if (percentage >= 40) return "󰁾";
      if (percentage >= 30) return "󰁽";
      if (percentage >= 20) return "󰁼";
      if (percentage >= 10) return "󰁻";
      return "󰁺";
    }
  }

  function getBatteryColor() {
    if (isCharging) return Theme.success;
    if (warningLevel === "critical" || percentage <= 10) return Theme.error;
    if (warningLevel === "low" || percentage <= 20) return Theme.info;
    return Theme.accentAlt;
  }

  function getBatteryStatus() {
    let status = isCharging ? "Charging" : "Discharging";
    let details = `${status}: ${percentage}%`;
    if (timeRemaining && timeRemaining !== "N/A") {
      details += isCharging ? ` (${timeRemaining} to full)` : ` (${timeRemaining} remaining)`;
    }
    return details;
  }

  PollingProcess {
    id: batteryChecker
    interval: 20000
    command: ["sh", "-c", `
      upower -i /org/freedesktop/UPower/devices/DisplayDevice | awk '
        /state:/ { state = $2 }
        /percentage:/ { 
          percentage = $2; 
          gsub(/%/, "", percentage) 
        }
        /time to empty:/ { 
          for(i=4; i<=NF; i++) time_remaining = time_remaining " " $i
          time_remaining = substr(time_remaining, 2)
        }
        /time to full:/ { 
          for(i=4; i<=NF; i++) time_remaining = time_remaining " " $i
          time_remaining = substr(time_remaining, 2)
        }
        /warning-level:/ { warning = $2 }
        END { 
          print state ";" percentage ";" time_remaining ";" warning 
        }
      '
    `]

    onDataReceived: data => {
      const parts = data.trim().split(';');
      if (parts.length >= 4) {
        const state = parts[0] || "";
        const pct = parseInt(parts[1]) || 0;
        const time = parts[2] || "";
        const warning = parts[3] || "none";

        root.isCharging = (state === "charging");
        root.isDischarging = (state === "discharging");
        root.percentage = pct;
        root.timeRemaining = time.trim();
        root.warningLevel = warning;
      }
    }
  }

  // Charging animation
  SequentialAnimation {
    running: root.isCharging
    loops: Animation.Infinite
    
    PropertyAnimation {
      target: root
      property: "opacity"
      from: 1.0
      to: 0.7
      duration: 1500
      easing.type: Easing.InOutQuad
    }
    
    PropertyAnimation {
      target: root
      property: "opacity"
      from: 0.7
      to: 1.0
      duration: 1500
      easing.type: Easing.InOutQuad
    }
  }

  MouseArea {
    anchors.fill: parent
    onClicked: {
      Notify.send("Battery Status", root.getBatteryStatus());
    }
  }

  // Low battery notifications
  onPercentageChanged: {
    if (percentage <= 10 && !isCharging) {
      Notify.send("Critical Battery", `Battery critically low: ${percentage}%`);
    } else if (percentage <= 20 && !isCharging && percentage > 10) {
      Notify.send("Low Battery", `Battery low: ${percentage}%`);
    }
  }
}
