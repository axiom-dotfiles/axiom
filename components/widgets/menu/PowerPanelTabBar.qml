pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.services
import qs.config

Rectangle {
    id: root
    
    property int currentTab: 0
    property var tabs: []
    signal tabClicked(int index)
    
    color: Colors.surfaceAlt
    
    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: Settings.widgetPadding
        anchors.rightMargin: Settings.widgetPadding
        spacing: Settings.widgetSpacing
        
        Repeater {
            model: root.tabs
            
            delegate: TabButton {
                required property int index
                required property var modelData
                
                Layout.fillWidth: true
                Layout.fillHeight: true
                text: modelData.name
                checked: root.currentTab === index
                
                contentItem: Text {
                    text: parent.text
                    font.family: Settings.fontFamily
                    font.pixelSize: Settings.fontSize - 2
                    color: parent.checked ? Colors.accent : Colors.textSecondary
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }
                
                background: Rectangle {
                    color: parent.checked ? Colors.surfaceAlt2 : "transparent"
                    radius: Settings.borderRadius
                    
                    Rectangle {
                        anchors.bottom: parent.bottom
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: parent.width * 0.8
                        height: 2
                        color: Colors.accent
                        visible: parent.parent.checked
                        radius: 1
                    }
                }
                
                onClicked: {
                    root.tabClicked(index)
                }
            }
        }
    }
    
    // Bottom separator
    Rectangle {
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        height: Settings.borderWidth
        color: Colors.accent2
    }
}
