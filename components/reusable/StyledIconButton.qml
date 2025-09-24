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
    
    Layout.preferredWidth: Widget.height
    Layout.preferredHeight: Widget.height
    
    contentItem: Text {
        text: button.iconText
        font.family: Appearance.fontFamily
        font.pixelSize: button.iconSize
        color: iconColor
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
    }
    
    background: Rectangle {
        color: button.hovered ? Theme.backgroundHighlight : "transparent"
        radius: Appearance.borderRadius
        
        Behavior on color {
            ColorAnimation { duration: 150 }
        }
    }
    
    ToolTip {
        visible: button.hovered && button.tooltipText !== ""
        text: button.tooltipText
        delay: 500
        font.family: Appearance.fontFamily
        font.pixelSize: Appearance.fontSize - 4
        
        background: Rectangle {
            color: Theme.backgroundAlt
            border.color: Theme.border
            border.width: 1
            radius: Appearance.borderRadius
        }
    }
}
