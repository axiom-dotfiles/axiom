pragma ComponentBehavior: Bound
import QtQuick

import qs.services
import qs.config

// Caffeine toggle: while on, the compositor (and hypridle) won't treat the
// session as idle. The state and the inhibitor itself live outside the bar
// (IdleInhibitManager, shell/IdleInhibit), so every bar's widget, the IPC
// target and the quick action stay in sync.
BarIconWidget {
  id: root

  icon: IdleInhibitManager.enabled ? "coffee" : "bedtime"
  text: I18n.tr(IdleInhibitManager.enabled ? "Awake" : "Idle")
  showText: properties.showLabel

  backgroundColor: Theme.resolveColor(IdleInhibitManager.enabled ? properties.activeColor : properties.inactiveColor)
  opacity: mouseArea.pressed ? 0.8 : 1

  MouseArea {
    id: mouseArea
    anchors.fill: parent
    cursorShape: Qt.PointingHandCursor
    onClicked: IdleInhibitManager.toggle()
  }
}
