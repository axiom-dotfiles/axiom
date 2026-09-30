pragma ComponentBehavior: Bound
import QtQuick

import qs.services
import qs.config

BarIconWidget {
  id: root

  // From UPower's display device (services/BatteryManager.qml)
  readonly property bool isCharging: BatteryManager.isCharging
  readonly property int percentage: BatteryManager.percentage
  readonly property string timeRemaining: isCharging ? BatteryManager.timeToFull : BatteryManager.timeRemaining
  // "none" / "low" / "critical": the last level notified about, so each
  // threshold notifies once per crossing
  property string _notifiedLevel: "none"
  // No laptop battery (a desktop): collapse to nothing, so a default bar
  // can carry the widget on any machine
  readonly property bool hidden: !BatteryManager.isAvailable

  readonly property string level: {
    if (isCharging)
      return "none";
    if (percentage <= properties.criticalThreshold)
      return "critical";
    if (percentage <= properties.lowThreshold)
      return "low";
    return "none";
  }

  icon: BatteryManager.getBatteryIcon()
  text: `${percentage}%`
  showIcon: !hidden
  showText: properties.showPercentage && !hidden
  padding: hidden ? 0 : root.barConfig.widgetPadding

  backgroundColor: getBatteryColor()

  iconScale: 1.1
  textScale: 0.9

  function getBatteryColor() {
    if (isCharging)
      return Theme.resolveColor(properties.chargingColor);
    if (level === "critical")
      return Theme.resolveColor(properties.criticalColor);
    if (level === "low")
      return Theme.resolveColor(properties.lowColor);
    return Theme.resolveColor(properties.backgroundColor);
  }

  function getBatteryStatus() {
    let status = I18n.tr(isCharging ? "Charging" : "Discharging");
    let details = I18n.tr("{0}: {1}%", status, percentage);
    if (timeRemaining) {
      details += " " + (isCharging ? I18n.tr("({0} to full)", timeRemaining) : I18n.tr("({0} remaining)", timeRemaining));
    }
    return details;
  }

  // Charging animation
  SequentialAnimation {
    running: root.isCharging && !root.hidden && Appearance.animations
    loops: Animation.Infinite

    PropertyAnimation {
      target: root
      property: "opacity"
      from: 1.0
      to: 0.7
      duration: Appearance.animSlow * 5
      easing.type: Easing.InOutQuad
    }

    PropertyAnimation {
      target: root
      property: "opacity"
      from: 0.7
      to: 1.0
      duration: Appearance.animSlow * 5
      easing.type: Easing.InOutQuad
    }
  }

  MouseArea {
    anchors.fill: parent
    enabled: !root.hidden
    onClicked: {
      NotificationManager.sendNotification("axiom", I18n.tr("Battery Status"), root.getBatteryStatus());
    }
  }

  // Low battery notifications, once each time a threshold is crossed
  onLevelChanged: {
    if (properties.notify && !hidden && level !== _notifiedLevel) {
      if (level === "critical")
        NotificationManager.sendNotification("axiom", I18n.tr("Critical Battery"), I18n.tr("Battery critically low: {0}%", percentage));
      else if (level === "low" && _notifiedLevel !== "critical")
        NotificationManager.sendNotification("axiom", I18n.tr("Low Battery"), I18n.tr("Battery low: {0}%", percentage));
    }
    _notifiedLevel = level;
  }
}
