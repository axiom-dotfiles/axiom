pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts

import qs.services
import qs.config
import qs.components.methods
import qs.components.widgets.menu
import qs.components.reusable

StyledContainer {
    id: root
    
    implicitWidth: 500
    implicitHeight: topSectionHeight + scrollableContentHeight + quickSettingsHeight + 
                    (mediaPlaying ? 80 : 0) + 
                    (Widget.containerWidth * (mediaPlaying ? 5 : 4))
    
    property real topSectionHeight: 120
    property real scrollableContentHeight: 500
    property real quickSettingsHeight: 60
    property bool mediaPlaying: false
    
    containerBorderColor: Theme.border
    containerBorderWidth: Appearance.borderWidth
    
    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 10
        spacing: Widget.containerWidth
        
        StyledContainer {
            Layout.fillWidth: true
            Layout.preferredHeight: root.topSectionHeight
            containerBorderColor: Theme.border
            
            StyledText {
                anchors.centerIn: parent
                text: "Top Section - Reserved for Future Component"
                textColor: Theme.foregroundAlt
            }
        }
        
        PowerPanelTabs {
            id: tabbedContent
            Layout.fillWidth: true
            Layout.preferredHeight: root.scrollableContentHeight
        }
        
        PowerPanelMediaControl {
            id: mediaControl
            Layout.fillWidth: true
            playing: root.mediaPlaying
        }
        
        PowerPanelQuickSettings {
            Layout.fillWidth: true
            Layout.preferredHeight: 60
        }
    }
    
    Timer {
        interval: 3000
        running: true
        onTriggered: {
            root.mediaPlaying = true
        }
    }
}
