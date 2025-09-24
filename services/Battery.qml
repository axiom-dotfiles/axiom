pragma Singleton;
import QtQuick
import Quickshell
import Quickshell.Services.UPower

QtObject {
  id: root

  property UPowerDevice battery: null
  property bool isAvailable: battery !== null
  property int percentage: battery?.percentage ?? 0
  property bool isCharging: battery?.state === UPowerDeviceState.Charging
  property bool isDischarging: battery?.state === UPowerDeviceState.Discharging
  property bool isFull: battery?.state === UPowerDeviceState.FullyCharged
  property bool isLow: percentage <= 20
  property bool isCritical: percentage <= 10
  property string timeRemaining: formatTime(battery?.timeToEmpty ?? 0)
  property string timeToFull: formatTime(battery?.timeToFull ?? 0)

  Component.onCompleted: {
    findBattery();
  }

  function findBattery() {
    const devices = UPower.devices;
    for (let i = 0; i < devices.length; i++) {
      const device = devices[i];
      if (device.type === UPowerDeviceType.Battery) {
        battery = device;
        break;
      }
    }
  }

  function formatTime(seconds) {
    if (seconds <= 0)
      return "";

    const hours = Math.floor(seconds / 3600);
    const minutes = Math.floor((seconds % 3600) / 60);

    if (hours > 0) {
      return `${hours}h ${minutes}m`;
    } else {
      return `${minutes}m`;
    }
  }

  function getBatteryIcon() {
    if (isCharging) {
      if (percentage >= 90)
        return "󰂅";
      if (percentage >= 80)
        return "󰂋";
      if (percentage >= 60)
        return "󰂊";
      if (percentage >= 40)
        return "󰢞";
      if (percentage >= 20)
        return "󰢝";
      return "󰢜";
    } else {
      if (percentage >= 90)
        return "󰁹";
      if (percentage >= 80)
        return "󰂂";
      if (percentage >= 70)
        return "󰂁";
      if (percentage >= 60)
        return "󰂀";
      if (percentage >= 50)
        return "󰁿";
      if (percentage >= 40)
        return "󰁾";
      if (percentage >= 30)
        return "󰁽";
      if (percentage >= 20)
        return "󰁼";
      if (percentage >= 10)
        return "󰁻";
      return "󰁺";
    }
  }

  function getBatteryColor() {
    if (isCharging)
      return Theme.success;
    if (isCritical)
      return Theme.error;
    if (isLow)
      return Theme.warning;
    return Theme.backgroundHighlight;
  }

  function getBatteryStatus() {
    if (isCharging) {
      return `Charging: ${percentage}%${timeToFull ? ` (${timeToFull} to full)` : ''}`;
    } else if (isDischarging) {
      return `Discharging: ${percentage}%${timeRemaining ? ` (${timeRemaining} remaining)` : ''}`;
    } else if (isFull) {
      return `Battery Full: ${percentage}%`;
    } else {
      return `Battery: ${percentage}%`;
    }
  }
}
