pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import qs.services
import qs.config
import qs.components.reusable

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
                
                onClicked: root.tabClicked(index)
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
