pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts

import qs.services
import qs.config
import qs.components.methods
import qs.components.reusable

StyledContainer {
    id: root

    RowLayout {
        anchors.fill: parent
        spacing: Widget.padding
        Layout.alignment: Qt.AlignHCenter | Qt.AlignVCenter

        StyledIconButton {
            iconText: "󰖩"
            tooltipText: "Network Manager"
            onClicked: Utils.launch("nm-connection-editor")
            backgroundColor: Theme.base0A
            iconColor: Theme.background
        }

        StyledIconButton {
            iconText: "󰂯"
            tooltipText: "Bluetooth Manager"
            onClicked: Utils.launch("blueberry")
            backgroundColor: Theme.base0B
            iconColor: Theme.background
        }

        StyledIconButton {
            iconText: "󰃣"
            tooltipText: "Appearance Settings"
            onClicked: Utils.launch("nwg-look")
            backgroundColor: Theme.base0C
            iconColor: Theme.background
        }

        StyledIconButton {
            iconText: "󰕾"
            tooltipText: "Audio Control"
            onClicked: Utils.launch("pavucontrol")
            backgroundColor: Theme.base0D
            iconColor: Theme.background
        }
    }
}
