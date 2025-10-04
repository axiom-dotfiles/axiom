import QtQuick
import Qt5Compat.GraphicalEffects
import Quickshell
import Quickshell.Services.Notifications
import qs.config

Rectangle {
    id: root

    property string appIcon: ""
    property string summary: ""
    property int urgency: NotificationUrgency.Normal
    property string image: ""

    property int baseSize: Bar.extent

    implicitWidth: baseSize
    implicitHeight: baseSize
    radius: width / 2 // Full rounding
    color: Theme.accentAlt

    // --- Logic for icon sizes based on baseSize ---
    readonly property real materialIconScale: 0.6
    readonly property real appIconScale: 0.8
    readonly property real smallAppIconScale: 0.5

    // Fallback: Material Symbol
    Loader {
        id: materialSymbolLoader
        active: root.appIcon === ""
        anchors.fill: parent
        sourceComponent: Text {
            font.family: "Material Symbols Outlined" // Assuming this font is available
            text: root.urgency === NotificationUrgency.Critical ? "priority_high" : "notifications"
            color: Theme.base00
            font.pixelSize: root.baseSize * root.materialIconScale
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
        }
    }

    // Default: App Icon
    Loader {
        id: appIconLoader
        active: root.image === "" && root.appIcon !== ""
        anchors.centerIn: parent
        sourceComponent: Image {
            width: root.baseSize * root.appIconScale
            height: root.baseSize * root.appIconScale
            asynchronous: true
            source: Quickshell.iconPath(root.appIcon, "image-missing")
        }
    }

    // Override: Notification Image
    Loader {
        id: notifImageLoader
        active: root.image !== ""
        anchors.fill: parent
        sourceComponent: Item {
            anchors.fill: parent
            Image {
                id: notifImage
                anchors.fill: parent
                source: root.image
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                layer.enabled: true
                layer.effect: OpacityMask {
                    maskSource: Rectangle {
                        width: notifImage.width
                        height: notifImage.height
                        radius: notifImage.width / 2
                    }
                }
            }
            // Overlay small app icon on the image
            Loader {
                active: root.appIcon !== ""
                anchors.bottom: parent.bottom
                anchors.right: parent.right
                sourceComponent: Image {
                    width: root.baseSize * root.smallAppIconScale
                    height: root.baseSize * root.smallAppIconScale
                    asynchronous: true
                    source: Quickshell.iconPath(root.appIcon, "image-missing")
                }
            }
        }
    }
}
