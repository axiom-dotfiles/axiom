import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import qs.services
import qs.config

Rectangle {
    id: root
    
    property bool playing: false
    
    color: Colors.surfaceAlt
    radius: Settings.borderRadius
    visible: Layout.preferredHeight > 0
    clip: true

    border.color: Colors.accent2
    
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
        anchors.margins: Settings.widgetPadding
        active: root.playing
        
        sourceComponent: RowLayout {
            spacing: Settings.widgetSpacing
            
            // Album art placeholder
            Rectangle {
                Layout.preferredWidth: 60
                Layout.preferredHeight: 60
                color: Colors.surfaceAlt2
                radius: Settings.borderRadius
            }
            
            // Track info
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2
                
                Text {
                    text: "Track Title"
                    font.family: Settings.fontFamily
                    font.pixelSize: Settings.fontSize - 2
                    color: Colors.textPrimary
                    elide: Text.ElideRight
                }
                
                Text {
                    text: "Artist Name"
                    font.family: Settings.fontFamily
                    font.pixelSize: Settings.fontSize - 4
                    color: Colors.textSecondary
                    elide: Text.ElideRight
                }
            }
            
            // Media controls
            RowLayout {
                spacing: Settings.widgetSpacing
                
                MediaControlButton {
                    iconText: "󰒮"  // Previous icon
                    onClicked: console.log("Previous")
                }
                
                MediaControlButton {
                    iconText: "󰏤"  // Pause icon (or 󰐊 for play)
                    iconSize: Settings.fontSize + 4
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
        property int iconSize: Settings.fontSize
        
        Layout.preferredWidth: Settings.widgetHeight
        Layout.preferredHeight: Settings.widgetHeight
        
        contentItem: Text {
            text: parent.iconText
            font.family: Settings.fontFamily
            font.pixelSize: parent.iconSize
            color: Colors.textPrimary
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
        }
        
        background: Rectangle {
            color: parent.hovered ? Colors.surfaceAlt2 : "transparent"
            radius: Settings.borderRadius
            
            Behavior on color {
                ColorAnimation { duration: 150 }
            }
        }
    }
}
