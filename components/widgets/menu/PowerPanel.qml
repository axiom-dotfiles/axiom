pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Effects

import qs.services
import qs.config
import qs.components.methods
import qs.components.widgets.menu

Rectangle {
    id: root
    
    // Dimensions
    implicitWidth: 500
    
    // Dynamic height options:
    // Option 1: Auto-calculate based on content
    implicitHeight: topSectionHeight + scrollableContentHeight + quickSettingsHeight + 
                    (mediaPlaying ? 80 : 0) + 
                    (Widget.containerWidth * (mediaPlaying ? 5 : 4))
    
    // Option 2: Allow external override with a fallback to screen-based calculation
    // property real panelHeight: -1  // Set to -1 for auto, or specify a fixed height
    // property real actualHeight: panelHeight > 0 ? panelHeight : 
                                // Settings.display.resolutionHeight - (Settings.screenMargin * 2)
    
    // Use actualHeight instead of implicitHeight if you want external control
    // implicitHeight: actualHeight
    
    // Configurable properties
    property real topSectionHeight: 120  // Space for additional component above tabs
    property real scrollableContentHeight: 400  // Adjustable scrollable area height
    property real quickSettingsHeight: 60  // Quick settings bar height
    
    // State management
    property bool mediaPlaying: false
    
    // Theme colors
    color: Theme.backgroundAlt
    border.color: Theme.border
    border.width: Appearance.borderWidth
    radius: Appearance.borderRadius
    
    // Shadow effect
    // layer.enabled: true
    // layer.effect: MultiEffect {
    //     shadowEnabled: true
    //     shadowColor: Theme.dark ? "#80000000" : "#40000000"
    //     shadowHorizontalOffset: Colors.dark ? 2 : 1
    //     shadowVerticalOffset: Colors.dark ? 2 : 1
    //     shadowBlur: Colors.dark ? 0.8 : 0.6
    //     shadowScale: 1.02
    // }
    
    // Main layout
    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 10
        spacing: Widget.containerWidth
        
        // Top Section (for future component)
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: root.topSectionHeight
            color: Theme.backgroundAlt
            radius: Appearance.borderRadius
            border.color: Theme.border
            
            Text {
                anchors.centerIn: parent
                text: "Top Section - Reserved for Future Component"
                font.family: Appearance.fontFamily
                font.pixelSize: Appearance.fontSize
                color: Theme.foregroundAlt
            }
            
            // Bottom separator
            // Rectangle {
            //     anchors.bottom: parent.bottom
            //     anchors.left: parent.left
            //     anchors.right: parent.right
            //     height: Settings.borderWidth
            //     color: Theme.base0A
            // }
        }
        
        // Spacing
        // Item {
        //     Layout.fillWidth: true
        //     Layout.preferredHeight: Settings.containerWidth
        // }
        
        // Tabbed Content Section (tabs + scrollable content)
        PowerPanelTabs {
            id: tabbedContent
            Layout.fillWidth: true
            Layout.preferredHeight: root.scrollableContentHeight
        }
        
        // Spacing
        // Item {
        //     Layout.fillWidth: true
        //     Layout.preferredHeight: Settings.containerWidth
        // }
        
        // Media Control Section
        PowerPanelMediaControl {
            id: mediaControl
            Layout.fillWidth: true
            playing: root.mediaPlaying
        }
        
        // Spacing (only if media control is visible)
        // Item {
        //     Layout.fillWidth: true
        //     Layout.preferredHeight: mediaControl.playing ? Settings.containerWidth : 0
        //     visible: mediaControl.playing
        //     
        //     Behavior on Layout.preferredHeight {
        //         NumberAnimation {
        //             duration: 200
        //             easing.type: Easing.InOutQuad
        //         }
        //     }
        // }
        
        // Quick Settings Bar
        PowerPanelQuickSettings {
            Layout.fillWidth: true
            Layout.preferredHeight: 60
        }

        // Item {
        //     Layout.fillWidth: true
        //     Layout.preferredHeight: Settings.containerWidth
        //     Rectangle {
        //         anchors.fill: parent
        //         color: "red"
        //     }
        // }
    }
    
    // Test timer to simulate media playback
    Timer {
        interval: 3000
        running: true
        onTriggered: {
            root.mediaPlaying = true
        }
    }
}
