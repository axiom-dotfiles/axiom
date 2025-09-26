pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts

import qs.services
import qs.config
import qs.components.reusable
import qs.components.widgets.menu

StyledContainer {
    id: root
    
    property int currentTab: 0
    property var tabs: []
    signal tabClicked(int index)
    
    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: Widget.padding
        anchors.rightMargin: Widget.padding

        Repeater {
            model: root.tabs
            
            delegate: StyledTabButton {
                required property int index
                required property var modelData
                
                text: modelData.name
                checked: root.currentTab === index
                Layout.preferredWidth: root.currentTab === index ? 3 : null
                
                onClicked: root.tabClicked(index)
                Behavior on Layout.preferredWidth {
                    NumberAnimation {
                        duration: 250
                        easing.type: Easing.InOutQuad
                    }
                }
            }
        }
    }
    
    StyledSeparator {
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        separatorColor: "transparent"
        separatorHeight: 10
    }
}
