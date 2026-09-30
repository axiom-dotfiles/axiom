pragma Singleton
import QtQuick
import Quickshell.Services.UPower

import qs.config

// The laptop battery (UPower's display device, when it is one) and the
// power-saver profile, for the Battery widget and popout, and the low
// battery notifications.
QtObject {
  id: root

  readonly property UPowerDevice battery: UPower.displayDevice?.isLaptopBattery ? UPower.displayDevice : null
  readonly property bool isAvailable: battery !== null
  // UPowerDevice.percentage is a 0-1 ratio
  readonly property int percentage: Math.round((battery?.percentage ?? 0) * 100)
  readonly property bool isCharging: battery?.state === UPowerDeviceState.Charging
  readonly property bool isFull: battery?.state === UPowerDeviceState.FullyCharged
  readonly property bool isLow: percentage <= 20
  readonly property bool isCritical: percentage <= 10
  // "2h 5m", "" when unknown
  readonly property string timeRemaining: formatTime(battery?.timeToEmpty ?? 0)
  readonly property string timeToFull: formatTime(battery?.timeToFull ?? 0)

  // power-profiles-daemon, over D-Bus. Quickshell can't tell whether the
  // daemon is there, so its CLI being installed stands in for it
  readonly property bool hasPowerProfiles: DependencyManager.found.powerprofilesctl === true
  readonly property bool powerSaver: hasPowerProfiles && PowerProfiles.profile === PowerProfile.PowerSaver

  // "none" / "low" / "critical": the last level notified about, shared by
  // every Battery widget so a threshold crossing notifies once however many
  // bars show one
  property string _notifiedLevel: "none"

  // A Battery widget with `notify` on reports its level (from its
  // thresholds); each crossing into low or critical notifies once
  function reportLevel(level) {
    if (level === root._notifiedLevel)
      return;
    if (level === "critical")
      NotificationManager.sendNotification("axiom", I18n.tr("Critical Battery"), I18n.tr("Battery critically low: {0}%", root.percentage));
    else if (level === "low" && root._notifiedLevel !== "critical")
      NotificationManager.sendNotification("axiom", I18n.tr("Low Battery"), I18n.tr("Battery low: {0}%", root.percentage));
    root._notifiedLevel = level;
  }

  function setPowerSaver(on) {
    PowerProfiles.profile = on ? PowerProfile.PowerSaver : PowerProfile.Balanced;
  }

  Component.onCompleted: DependencyManager.check(["powerprofilesctl"])

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
      if (percentage >= 60)
        return "battery_5_bar";
      if (percentage >= 50)
        return "battery_4_bar";
      if (percentage >= 30)
        return "battery_3_bar";
      if (percentage >= 20)
        return "battery_2_bar";
      return "battery_1_bar";
    }
  }
}
