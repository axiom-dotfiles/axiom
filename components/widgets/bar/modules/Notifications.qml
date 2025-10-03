pragma ComponentBehavior: Bound

import QtQuick

import qs.config
import qs.services
import qs.components.reusable
import qs.components.widgets.bar

// IconTextWidget {
//   id: root
//   icon: ""
//   backgroundColor: Theme.accent
//
//   // Open swaync panel; run detached so Quickshell isn’t tied to its lifecycle.
//   Process {
//     id: openPanel
//     command: ["swaync-client", "-op", "-sw"]
//     // we only want a one-shot detached spawn:
//     onStarted: {
//       openPanel.startDetached();
//       openPanel.running = false;
//     }
//   }
//
//   MouseArea {
//     anchors.fill: parent
//     hoverEnabled: true
//     cursorShape: Qt.PointingHandCursor
//     onClicked: openPanel.running = true
//   }
// }

BarModule {
  content: StyledRectButton {
    id: component

    // -- Signals --
    // null

    // -- Public API --
    // null

    // -- Configurable Appearance --
    iconText: ""
    iconColor: Theme.background
    borderHoverColor: Theme.accent
    backgroundColor: Theme.accent

    // -- Implementation --
    onClicked: ShellManager.togglePinnedPanel("mainMenu")
  }
}
