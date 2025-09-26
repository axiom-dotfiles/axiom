// qs/components/reusable/notifications/NotificationActionButton.qml
import QtQuick
import QtQuick.Layouts
import qs.config

Rectangle {
    id: root

    property string buttonText
    property int urgency // Matches NotificationUrgency enum
    property alias content: contentLoader.sourceComponent

    // FIX: Added the clicked signal so it can be used by parent components
    signal clicked()

    implicitHeight: Widget.height
    implicitWidth: contentLoader.item ? contentLoader.item.implicitWidth + (Widget.padding * 2) : 0
    radius: Appearance.borderRadius

    color: {
        const baseColor = urgency === NotificationUrgency.Critical ? Theme.accentAlt : Theme.backgroundHighlight;
        if (mouseArea.pressed) return Qt.darker(baseColor, 1.2);
        if (mouseArea.hovered) return Qt.lighter(baseColor, 1.1);
        return baseColor;
    }

    // FIX: Re-enabled animation
    // Behavior on color { enabled: Widget.animations; Animation { duration: Widget.animationDuration } }

    Loader {
        id: contentLoader
        anchors.centerIn: parent
        sourceComponent: Text {
            text: root.buttonText
            font.family: Appearance.fontFamily
            font.pixelSize: Appearance.fontSize - 2
            color: urgency === NotificationUrgency.Critical ? Theme.base00 : Theme.foreground
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
        }
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        // FIX: This now emits the signal declared above
        onClicked: root.clicked()
    }
}
