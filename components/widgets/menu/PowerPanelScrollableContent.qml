import QtQuick
import QtQuick.Controls

import qs.services
import qs.config

ScrollView {
    id: root
    
    contentWidth: width - ScrollBar.vertical.width
    ScrollBar.vertical.policy: ScrollBar.AsNeeded
    ScrollBar.horizontal.policy: ScrollBar.AlwaysOff

    bottomPadding: Widget.padding
    
    // Custom scrollbar styling
    ScrollBar.vertical {
        parent: root
        x: root.width - width
        y: 0
        height: root.availableHeight
        active: true
        
        contentItem: Rectangle {
            implicitWidth: 6
            radius: 3
            color: Theme.accent
            opacity: parent.pressed ? 0.8 : 0.4
            
            Behavior on opacity {
                NumberAnimation { duration: 150 }
            }
        }
        
        background: Rectangle {
            implicitWidth: 8
            color: Theme.backgroundAlt
            opacity: 0.2
            radius: 4
        }
    }
}
