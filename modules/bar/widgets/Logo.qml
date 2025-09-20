import QtQuick
import Quickshell
import Quickshell.Io

import qs.services
import qs.components.widgets

IconTextWidget {
  id: root

  backgroundColor: Colors.accent2
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
