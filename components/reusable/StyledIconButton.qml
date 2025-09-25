// qs/components/reusable/StyledIconButton.qml
pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import qs.config
import qs.components.reusable

ToolButton {
    id: button
    
    property string iconText: ""
    property int iconSize: Appearance.fontSize
    property string tooltipText: ""
    property color iconColor: Theme.foreground

    property color hoverColor: Theme.backgroundHighlight
    property color pressColor: Theme.backgroundAlt

    property color backgroundColor: "transparent"
    property color borderColor: "transparent"
    property int borderWidth: Appearance.borderWidth
    property real borderRadius: Appearance.borderRadius

    Layout.fillHeight: true
    Layout.fillWidth: true
    Layout.alignment: Qt.AlignHCenter | Qt.AlignVCenter

    contentItem: Text {
        text: button.iconText
        font.family: Appearance.fontFamily
        font.pixelSize: button.iconSize
        color: iconColor
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
    }

    background: Rectangle {
        id: backgroundRect
        // color: button.buttonClicked ? button.pressColor : button.backgroundColor
        color: button.pressed ? button.pressColor : (button.hovered ? button.hoverColor : button.backgroundColor)
        border.color: button.borderColor
        border.width: button.borderWidth
        radius: button.borderRadius
        
        Behavior on color {
            ColorAnimation { duration: 150 }
        }
    }
}
