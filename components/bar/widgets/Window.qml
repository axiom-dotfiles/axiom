pragma ComponentBehavior: Bound

import Quickshell.Wayland

BarIconWidget {
  id: root

  // Grows with the title up to preferredSize, and gives way when crowded
  readonly property string sizePolicy: "elastic"
  readonly property int preferredSize: 240
  readonly property int minimumSize: 80

  icon: properties.icon
  text: ToplevelManager.activeToplevel?.title || properties.emptyText
}
