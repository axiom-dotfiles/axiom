pragma ComponentBehavior: Bound

import QtQuick

import qs.config
import qs.services
import qs.components.reusable
import qs.components.hosts.popout

// The notification bell: a badge with the count, the do-not-disturb icon
// while it's on. Click toggles do-not-disturb, middle click clears every
// notification; hovering opens the notification list.
BarIconWidget {
  id: root

  icon: NotificationManager.dnd ? "notifications_off" : "notifications"
  showText: false
  iconColor: NotificationManager.dnd ? Theme.resolveColor(properties.dndColor) : colors.icon

  clickable: true
  acceptedButtons: Qt.LeftButton | Qt.MiddleButton
  onClicked: button => {
    if (button === Qt.MiddleButton)
      NotificationManager.clearAll();
    else
      NotificationManager.toggleDnd();
  }

  // On the icon's top-right corner
  Rectangle {
    visible: root.properties.showCount && NotificationManager.count > 0
    x: Math.round((root.width + root.iconLength) / 2 - width / 2)
    y: 1
    implicitWidth: Math.max(14, badgeLabel.implicitWidth + 6)
    implicitHeight: 14
    radius: height / 2
    color: Theme.resolveColor(root.properties.badgeColor)

    StyledText {
      id: badgeLabel
      anchors.centerIn: parent
      text: NotificationManager.countLabel
      textSize: Appearance.fontSize - 4
      textColor: Theme.background
    }
  }

  PopoutAnchor {
    popouts: root.popouts
    panel: root.panel
    hitArea: root.hitArea
    popoutName: "Notifications"
    active: root.properties.showPopout
    openDelay: 150
  }
}
