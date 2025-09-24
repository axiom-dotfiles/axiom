import QtQuick
import Quickshell
import Quickshell.Io

import qs.services
import qs.config
import qs.components.widgets.reusable

IconTextWidget {
  id: root

  backgroundColor: Theme.info
  icon: ""  // Arch logo (Nerd Font)

  Process {
    id: wlogout
    command: ["wlogout"]
    onStarted: { wlogout.startDetached(); wlogout.running = false }
  }
  MouseArea {
    anchors.fill: parent
    cursorShape: Qt.PointingHandCursor
    onClicked: wlogout.running = true
  }
}
