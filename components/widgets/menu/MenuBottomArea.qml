// components/widgets/menu/MenuBottomArea.qml
pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import qs.services
import qs.config
import qs.components.methods
import qs.components.reusable
import qs.components.widgets.menu

ColumnLayout {
    id: root
    
    property real quickSettingsHeight: 60
    property bool showMediaControl: true
    property bool mediaPlaying: true
    
    spacing: Widget.containerWidth // Internal spacing between items in this section
    
    MediaControl {
        id: mediaControl
        Layout.fillWidth: true
        visible: root.showMediaControl
        containerColor: Theme.accent
    }
    
    QuickSettings {
        Layout.fillWidth: true
        Layout.preferredHeight: root.quickSettingsHeight
    }
}
