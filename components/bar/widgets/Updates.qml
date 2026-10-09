pragma ComponentBehavior: Bound
import QtQuick

import qs.services
import qs.config
import qs.components.hosts.popout

// Pending package updates from UpdatesManager: repo packages via
// `checkupdates` (pacman-contrib, which uses a temporary sync db, so it never
// touches the real one), plus AUR packages via paru/yay when enabled. Left click opens a terminal to
// upgrade, right click checks again now; hovering lists the packages.
BarIconWidget {
  id: root

  // [{ name, from, to }], checked by the shared UpdatesManager
  readonly property var repoPackages: UpdatesManager.repoPackages
  readonly property var aurPackages: properties.includeAur ? UpdatesManager.aurPackages : []
  readonly property int count: repoPackages.length + aurPackages.length

  hidden: properties.hideWhenEmpty && count === 0
  readonly property string upgradeCommand: properties.upgradeCommand || (properties.includeAur ? `${properties.aurHelper} -Syu` : "sudo pacman -Syu")

  icon: "download"
  text: String(count)

  accentColor: Theme.resolveColor(count >= properties.manyThreshold ? properties.manyColor : properties.backgroundColor)

  // Re-acquiring replaces the old request
  readonly property var updatesRequest: ({
      "intervalMinutes": root.properties.intervalMinutes,
      "aurHelper": root.properties.includeAur ? root.properties.aurHelper : ""
    })
  onUpdatesRequestChanged: UpdatesManager.acquire(root, updatesRequest)
  Component.onCompleted: UpdatesManager.acquire(root, updatesRequest)
  Component.onDestruction: UpdatesManager.release(root)

  clickable: true
  acceptedButtons: Qt.LeftButton | Qt.RightButton
  onClicked: button => {
    if (button === Qt.RightButton)
      UpdatesManager.refresh();
    else
      UpdatesManager.upgrade(root.upgradeCommand, root.properties.terminal);
  }

  PopoutAnchor {
    hitArea: root.hitArea
    popoutName: "Updates"
    active: EdgeMenusConfig.opensOwnPopout(root.properties) && !root.hidden
    extraData: ({
        "repoPackages": root.repoPackages,
        "aurPackages": root.aurPackages
      })
  }
}
