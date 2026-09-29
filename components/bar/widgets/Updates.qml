pragma ComponentBehavior: Bound
import QtQuick
import Quickshell.Io

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

  readonly property bool hidden: properties.hideWhenEmpty && count === 0
  readonly property string upgradeCommand: properties.upgradeCommand || (properties.includeAur ? `${properties.aurHelper} -Syu` : "sudo pacman -Syu")

  icon: "download"
  text: String(count)
  showIcon: !hidden
  showText: !hidden
  padding: hidden ? 0 : root.barConfig.widgetPadding

  backgroundColor: Theme.resolveColor(count >= properties.manyThreshold ? properties.manyColor : properties.backgroundColor)
  opacity: mouseArea.pressed ? 0.8 : 1

  // Re-registering replaces the old request
  function register() {
    UpdatesManager.acquire(root, {
      "intervalMinutes": properties.intervalMinutes,
      "aurHelper": properties.includeAur ? properties.aurHelper : ""
    });
  }
  onPropertiesChanged: register()
  Component.onCompleted: register()
  Component.onDestruction: UpdatesManager.release(root)

  // Runs until the terminal closes, then re-checks
  Process {
    id: upgrader
    command: [root.properties.terminal, "-e", "bash", "-c", `${root.upgradeCommand}; echo; read -n 1 -s -r -p "Press any key to close"`]
    onExited: UpdatesManager.refresh()
  }

  MouseArea {
    id: mouseArea
    anchors.fill: parent
    enabled: !root.hidden
    cursorShape: Qt.PointingHandCursor
    acceptedButtons: Qt.LeftButton | Qt.RightButton
    onClicked: mouse => {
      if (mouse.button === Qt.RightButton)
        UpdatesManager.refresh();
      else if (!upgrader.running)
        upgrader.running = true;
    }
  }

  PopoutAnchor {
    popouts: root.popouts
    panel: root.panel
    popoutName: "Updates"
    active: root.properties.showPopout && !root.hidden
    extraData: ({
        "repoPackages": root.repoPackages,
        "aurPackages": root.aurPackages
      })
  }
}
