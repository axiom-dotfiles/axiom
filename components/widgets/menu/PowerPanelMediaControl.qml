import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import qs.services
import qs.config

Rectangle {
    id: root
    
    property bool playing: false
    
    color: Theme.backgroundAlt
    radius: Appearance.borderRadius
    visible: Layout.preferredHeight > 0
    clip: true

    border.color: Theme.accentAlt
    
    // This is what actually gets animated
    Layout.preferredHeight: playing ? 80 : 0
    
    Behavior on Layout.preferredHeight {
        NumberAnimation {
            duration: 200
            easing.type: Easing.InOutQuad
        }
    }
    
    // TODO: Load actual media controls here (MPRIS integration)
    Loader {
        id: mediaControlLoader
        anchors.fill: parent
        anchors.margins: Widget.padding
        active: root.playing
        
        sourceComponent: RowLayout {
            spacing: Widget.spacing
            
            // Album art placeholder
            Rectangle {
                Layout.preferredWidth: 60
                Layout.preferredHeight: 60
                color: Theme.backgroundHighlight
                radius: Appearance.borderRadius
            }
            
            // Track info
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2
                
                Text {
                    text: "Track Title"
                    font.family: Appearance.fontFamily
                    font.pixelSize: Appearance.fontSize - 2
                    color: Theme.foreground
                    elide: Text.ElideRight
                }
                
                Text {
                    text: "Artist Name"
                    font.family: Appearance.fontFamily
                    font.pixelSize: Appearance.fontSize - 4
                    color: Theme.foregroundAlt
                    elide: Text.ElideRight
                }
            }
            
            // Media controls
            RowLayout {
                spacing: Widget.spacing
                
                MediaControlButton {
                    iconText: "󰒮"  // Previous icon
                    onClicked: console.log("Previous")
                }
                
                MediaControlButton {
                    iconText: "󰏤"  // Pause icon (or 󰐊 for play)
                    iconSize: Appearance.fontSize + 4
                    onClicked: console.log("Play/Pause")
                }
                
                MediaControlButton {
                    iconText: "󰒭"  // Next icon
                    onClicked: console.log("Next")
                }
            }
        }
    }
    
    component MediaControlButton: ToolButton {
        property string iconText: ""
        property int iconSize: Appearance.fontSize
        
        Layout.preferredWidth: Widget.height
        Layout.preferredHeight: Widget.height
        
        contentItem: Text {
            text: parent.iconText
            font.family: Appearance.fontFamily
            font.pixelSize: parent.iconSize
            color: Theme.foreground
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
        }
        
        background: Rectangle {
            color: parent.hovered ? Theme.backgroundHighlight : "transparent"
            radius: Appearance.borderRadius
            
            Behavior on color {
                ColorAnimation { duration: 150 }
            }
        }
    }
}
