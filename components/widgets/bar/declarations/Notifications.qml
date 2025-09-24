pragma ComponentBehavior: Bound

import QtQuick
import Quickshell.Io

import qs.config
import qs.components.reusable

IconTextWidget {
  id: root
  icon: ""
  backgroundColor: Theme.accent

  // Open swaync panel; run detached so Quickshell isn’t tied to its lifecycle.
  Process {
    id: openPanel
    command: ["swaync-client", "-op", "-sw"]
    // we only want a one-shot detached spawn:
    onStarted: {
      openPanel.startDetached();
      openPanel.running = false;
    }
  }

  MouseArea {
    anchors.fill: parent
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    onClicked: openPanel.running = true
  }
}
