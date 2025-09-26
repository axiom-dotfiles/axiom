// qs/components/reusable/notifications/NotificationGroup.qml
import QtQuick
import QtQuick.Layouts
import qs.config
import qs.services
import Quickshell.Services.Notifications
import qs.components.reusable.notifications as Comp

Rectangle {
    id: root

    // --- FIX: This property is now named 'modelData' to receive data from the ListView's delegate ---
    required property var modelData

    readonly property var notifications: modelData?.notifications ?? [] // <-- Changed
    readonly property int notificationCount: notifications.length
    readonly property bool multipleNotifications: notificationCount > 1
    
    property bool expanded: false
    property real dragConfirmThreshold: 70
    property real xOffset: 0

    implicitHeight: mainColumn.implicitHeight + Widget.padding * 2
    // Behavior on implicitHeight { enabled: Widget.animations; Animation { duration: Widget.animationDuration } }

    radius: Appearance.borderRadius
    color: Theme.backgroundAlt
    clip: true
    anchors.leftMargin: root.xOffset
    
    // ... (rest of the file is the same, but uses 'modelData' instead of 'notificationGroup')

    function destroyWithAnimation() {
        anchors.leftMargin = anchors.leftMargin;
        destroyAnimation.start();
    }

    SequentialAnimation {
        id: destroyAnimation
        NumberAnimation {
            target: root
            property: "anchors.leftMargin"
            to: root.width + 20
            duration: Widget.animationDuration
            easing.type: Easing.InQuad
        }
        ScriptAction {
            script: {
                root.notifications.forEach(notif => notif.dismiss());
            }
        }
    }

    function toggleExpanded() {
        if (multipleNotifications) {
            root.expanded = !root.expanded;
        }
    }

    RowLayout {
        id: mainColumn
        anchors.fill: parent
        anchors.margins: Widget.padding
        spacing: Widget.padding

        Comp.NotificationIcon {
            Layout.alignment: Qt.AlignTop
            appIcon: modelData?.appIcon // <-- Changed
            summary: modelData?.notifications[root.notificationCount - 1]?.summary // <-- Changed
            image: root.multipleNotifications ? "" : modelData?.notifications[0]?.image ?? "" // <-- Changed
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: Widget.spacing

            RowLayout {
                Layout.fillWidth: true
                
                Text {
                    Layout.fillWidth: true
                    elide: Text.ElideRight
                    text: (root.multipleNotifications ? modelData?.appName : modelData?.notifications[0]?.summary) || "" // <-- Changed
                    font.family: Appearance.fontFamily
                    font.pixelSize: Appearance.fontSize
                    color: Theme.foreground
                }

                Text {
                    text: new Date(modelData?.time).toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' }) // <-- Changed
                    font.family: Appearance.fontFamily
                    font.pixelSize: Appearance.fontSize - 4
                    color: Theme.foregroundAlt
                }

                Comp.NotificationExpandButton {
                    count: root.notificationCount
                    expanded: root.expanded
                    visible: root.multipleNotifications
                    onClicked: root.toggleExpanded()
                    onAltAction: root.toggleExpanded()
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: Widget.spacing
                Repeater {
                    model: root.expanded ? root.notifications.slice().reverse() : root.notifications.slice().reverse().slice(0, 2)
                    delegate: Comp.NotificationItem {
                        anchors.left: parent.left
                        anchors.right: parent.right
                        notificationObject: modelData
                        expanded: root.expanded || !root.multipleNotifications
                        onlyNotification: !root.multipleNotifications
                        opacity: (!root.expanded && index === 1 && root.notificationCount > 2) ? 0.5 : 1
                        visible: root.expanded || (index < 2)
                    }
                }
            }
        }
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
        drag.axis: Drag.XAxis
        // drag.enabled: !expanded

        onClicked: (mouse) => {
            if (mouse.button === Qt.RightButton) {
                root.toggleExpanded();
            } else if (mouse.button === Qt.MiddleButton) {
                root.destroyWithAnimation();
            } else if (!expanded) {
                root.toggleExpanded();
            }
        }

        onPositionChanged: (mouse) => {
            if (drag.active) {
                root.xOffset = Math.max(0, mouse.x - pressPoint.x);
            }
        }

        onReleased: () => {
            if (root.xOffset > root.dragConfirmThreshold) {
                root.destroyWithAnimation();
            } else {
                root.xOffset = 0;
            }
        }
    }
}
