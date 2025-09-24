pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts

import qs.services
import qs.config
import qs.components.methods
import qs.components.reusable

StyledContainer {
    id: root

    StyledSeparator {
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
    }

    StyledRowLayout {
        anchors.fill: parent
        anchors.margins: Widget.padding

        StyledIconButton {
            iconText: "󰖩"
            tooltipText: "Network Manager"
            onClicked: Utils.launch("nm-connection-editor")
        }

        StyledIconButton {
            iconText: "󰂯"
            tooltipText: "Bluetooth Manager"
            onClicked: Utils.launch("blueberry")
        }

        StyledIconButton {
            iconText: "󰃣"
            tooltipText: "Appearance Settings"
            onClicked: Utils.launch("nwg-look")
        }

        StyledIconButton {
            iconText: "󰕾"
            tooltipText: "Audio Control"
            onClicked: Utils.launch("pavucontrol")
        }

        Item {
            Layout.fillWidth: true
        }
    }
}
