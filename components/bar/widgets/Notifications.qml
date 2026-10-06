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

  hasBackground: true
  accentColor: Theme.resolveColor(properties.backgroundColor)
  // Its WidgetGroup outlines it in the bar's widget shape while hovered
  readonly property bool hoverOutline: true
  readonly property bool hovered: anchor.hovered

  StyledRectButton {
    id: button
    anchors.fill: parent
    borderRadius: root.barConfig.radius
    iconSize: root.barConfig.fontSize

    iconText: NotificationManager.dnd ? "notifications_off" : "notifications"
    iconColor: NotificationManager.dnd ? Theme.resolveColor(root.properties.dndColor) : root.colors.icon
    // Its WidgetGroup draws the background and the hover outline
    backgroundColor: "transparent"

    badgeVisible: root.properties.showCount && NotificationManager.count > 0
    badgeBackgroundColor: Theme.resolveColor(root.properties.badgeColor)
    badgeText: NotificationManager.countLabel
  }

  PopoutAnchor {
    id: anchor
    popouts: root.popouts
    panel: root.panel
    hitArea: root.hitArea
    popoutName: "Notifications"
    active: root.properties.showPopout
    openDelay: 150
  }
}
