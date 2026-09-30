pragma ComponentBehavior: Bound

import QtQuick

import qs.config
import qs.services
import qs.components.reusable
import qs.components.hosts.popout

BarWidget {
  id: root

  implicitWidth: root.barConfig.widgetSize
  implicitHeight: root.barConfig.widgetSize

  StyledRectButton {
    id: button
    anchors.fill: parent
    borderRadius: root.barConfig.radius
    iconSize: root.barConfig.fontSize

    iconText: NotificationManager.dnd ? "notifications_off" : "notifications"
    iconColor: Theme.resolveColor(NotificationManager.dnd ? root.properties.dndColor : root.properties.foregroundColor)
    borderHoverColor: Theme.accent
    backgroundColor: Theme.resolveColor(root.properties.backgroundColor)

    badgeVisible: root.properties.showCount && NotificationManager.count > 0
    badgeBackgroundColor: Theme.resolveColor(root.properties.badgeColor)
    badgeText: NotificationManager.count > 99 ? "99+" : String(NotificationManager.count)
  }

  PopoutAnchor {
    popouts: root.popouts
    panel: root.panel
    popoutName: "Notifications"
    active: root.properties.showPopout
    openDelay: 150
  }
}
