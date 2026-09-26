pragma Singleton
import QtQuick
import Quickshell.Services.UPower

import qs.config

QtObject {
  id: root

  property UPowerDevice battery: UPower.displayDevice?.isLaptopBattery ? UPower.displayDevice : null
  property bool isAvailable: battery !== null
  // UPowerDevice.percentage is a 0-1 ratio
  property int percentage: Math.round((battery?.percentage ?? 0) * 100)
  property bool isCharging: battery?.state === UPowerDeviceState.Charging
  property bool isDischarging: battery?.state === UPowerDeviceState.Discharging
  property bool isFull: battery?.state === UPowerDeviceState.FullyCharged
  property bool isLow: percentage <= 20
  property bool isCritical: percentage <= 10
  property string timeRemaining: formatTime(battery?.timeToEmpty ?? 0)
  property string timeToFull: formatTime(battery?.timeToFull ?? 0)

  function formatTime(seconds) {
    if (seconds <= 0)
      return "";

    const hours = Math.floor(seconds / 3600);
    const minutes = Math.floor((seconds % 3600) / 60);

    if (hours > 0) {
      return I18n.tr("{0}h {1}m", hours, minutes);
    } else {
      return I18n.tr("{0}m", minutes);
    }
  }

  function getBatteryIcon() {
    if (isCharging) {
      if (percentage >= 90)
        return "battery_charging_full";
      if (percentage >= 80)
        return "battery_charging_90";
      if (percentage >= 60)
        return "battery_charging_80";
      if (percentage >= 40)
        return "battery_charging_60";
      if (percentage >= 20)
        return "battery_charging_50";
      return "battery_charging_20";
    } else {
      if (percentage >= 90)
        return "battery_full";
      if (percentage >= 80)
        return "battery_6_bar";
      if (percentage >= 70)
        return "battery_5_bar";
      if (percentage >= 60)
        return "battery_5_bar";
      if (percentage >= 50)
        return "battery_4_bar";
      if (percentage >= 40)
        return "battery_3_bar";
      if (percentage >= 30)
        return "battery_3_bar";
      if (percentage >= 20)
        return "battery_2_bar";
      if (percentage >= 10)
        return "battery_1_bar";
      return "battery_1_bar";
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
}
