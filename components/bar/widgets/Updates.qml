pragma ComponentBehavior: Bound
import QtQuick

import qs.services
import qs.config
import qs.components.hosts.popout

// Pending package updates from UpdatesManager: repo packages the way this
// distribution checks them (`checkupdates` on Arch, `dnf check-update` on
// Fedora; hidden on one UpdatesManager can't check), plus AUR packages via
// paru/yay when enabled on Arch. Left click opens a terminal to upgrade,
// right click checks again now; hovering lists the packages.
BarIconWidget {
  id: root

  // [{ name, from, to }], checked by the shared UpdatesManager
  readonly property var repoPackages: UpdatesManager.repoPackages
  readonly property var aurPackages: properties.includeAur && UpdatesManager.hasAur ? UpdatesManager.aurPackages : []
  readonly property int count: repoPackages.length + aurPackages.length

  hidden: !UpdatesManager.supported || (properties.hideWhenEmpty && count === 0)
  readonly property string upgradeCommand: properties.upgradeCommand || UpdatesManager.upgradeCommand(properties.includeAur ? properties.aurHelper : "")

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
