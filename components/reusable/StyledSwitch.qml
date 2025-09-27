pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls

import qs.config

Switch {
    id: control

    // Expose the checked property for external binding
    // property alias checked: control.checked

    // We don't use the text property of the Switch itself to allow for more flexible layouts
    // where the label and switch are separate items in a RowLayout.

    implicitWidth: 50
    implicitHeight: 26

    indicator: Rectangle {
        x: control.checked ? control.width - width - 2 : 2
        y: 2
        width: control.height - 4
        height: control.height - 4
        radius: (control.height - 4) / 2
        color: Theme.foreground

        Behavior on x {
            NumberAnimation {
                duration: 150
                easing.type: Easing.InOutQuad
            }
        }
    }

    background: Rectangle {
        implicitWidth: 50
        implicitHeight: 26
        radius: height / 2
        color: control.checked ? Theme.accent : Theme.backgroundHighlight
        border.color: Theme.border
        border.width: Appearance.borderWidth

        Behavior on color {
            ColorAnimation {
                duration: 150
            }
        }
    }
}
