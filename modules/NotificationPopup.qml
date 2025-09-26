import QtQuick
import Quickshell

// The root item, matching your project structure.
Scope {
    id: root

    // A PanelWindow is required to act as an anchor for the PopupWindow.
    // It's invisible and non-interactive.
    PanelWindow {
        id: anchorHost
        anchors.top: true
        anchors.left: true
        color: "transparent"
        mask: Region { width: 0; height: 0 }
    }

    // --- Static Test Popup ---
    // We create just one PopupWindow directly. No Repeater, no model, no functions.
    // Its lifetime is tied directly to the root Scope.
    PopupWindow {
        id: staticPopup

        width: 380
        height: 120
        visible: false // Make it appear immediately on load.

        // Statically position the popup on the screen.
        anchor.window: anchorHost
        anchor.rect.x: 20
        anchor.rect.y: 20

        // Simple content to verify it's visible.
        Rectangle {
            anchors.fill: parent
            color: "#282c34" // Dark grey background
            radius: 8
            border.color: "steelblue"
            border.width: 1

            Text {
                anchors.centerIn: parent
                text: "Static Test Notification"
                color: "white"
                font.pixelSize: 16
            }
        }
    }
}
