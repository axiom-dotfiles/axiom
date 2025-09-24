import QtQuick
import QtQuick.Layouts

import qs.services
import qs.config
import qs.components.reusable

StyledContainer {
    id: root
    
    property bool playing: false
    containerColor: Theme.accent
    
    visible: Layout.preferredHeight > 0
    clip: true
    
    Layout.preferredHeight: playing ? 80 : 0
    
    Behavior on Layout.preferredHeight {
        NumberAnimation {
            duration: 200
            easing.type: Easing.InOutQuad
        }
    }
    
    Loader {
        id: mediaControlLoader
        anchors.fill: parent
        anchors.margins: Widget.padding
        active: root.playing
        
        sourceComponent: StyledRowLayout {
            StyledContainer {
                Layout.preferredWidth: 60
                Layout.preferredHeight: 60
                containerColor: Theme.backgroundHighlight
                containerBorderColor: Theme.foreground
                // Image art goes here
            }
            
            StyledColumnLayout {
                Layout.fillWidth: true
                layoutSpacing: 2
                
                StyledText {
                    text: "Track Title"
                    textSize: Appearance.fontSize - 2
                    textColor: Theme.background
                    elide: Text.ElideRight
                }
                
                StyledText {
                    text: "Artist Name"
                    textSize: Appearance.fontSize - 4
                    textColor: Theme.backgroundAlt
                    elide: Text.ElideRight
                }
            }
            
            StyledRowLayout {
                StyledIconButton {
                    iconText: "󰒮"
                    onClicked: console.log("Previous")
                    iconColor: Theme.backgroundAlt
                }
                
                StyledIconButton {
                    iconText: "󰏤"
                    iconSize: Appearance.fontSize + 4
                    onClicked: console.log("Play/Pause")
                    iconColor: Theme.background
                }
                
                StyledIconButton {
                    iconText: "󰒭"
                    onClicked: console.log("Next")
                    iconColor: Theme.backgroundAlt
                }
            }
        }
    }
}
