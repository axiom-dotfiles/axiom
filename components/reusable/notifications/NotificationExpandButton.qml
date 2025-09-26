// qs/components/reusable/notifications/NotificationExpandButton.qml
import QtQuick
import QtQuick.Layouts
import qs.config

Rectangle {
    id: root

    required property int count
    required property bool expanded
    signal altAction()
    // FIX: Added the clicked signal
    signal clicked()

    implicitHeight: Widget.height * 0.8
    implicitWidth: contentRow.implicitWidth + Widget.padding
    radius: height / 2

    color: mouseArea.pressed ? Qt.darker(Theme.backgroundHighlight, 1.2) :
           mouseArea.hovered ? Qt.lighter(Theme.backgroundHighlight, 1.1) :
           Theme.backgroundHighlight

    // FIX: Re-enabled animation
    // Behavior on color { enabled: Widget.animations; Animation { duration: Widget.animationDuration } }

    RowLayout {
        id: contentRow
        anchors.centerIn: parent
        spacing: Widget.spacing / 2

        Text {
            visible: root.count > 1
            text: root.count
            font.family: Appearance.fontFamily
            font.pixelSize: Appearance.fontSize - 4
            color: Theme.foreground
        }
        Text {
            text: "expand_more"
            font.family: "Material Symbols Outlined"
            font.pixelSize: Appearance.fontSize
            color: Theme.foreground
            rotation: root.expanded ? 180 : 0
            Behavior on rotation {
                enabled: Widget.animations
                NumberAnimation { duration: Widget.animationDuration; easing.type: Easing.InOutQuad }
            }
        }
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: (mouse) => {
            if (mouse.button === Qt.RightButton) {
                root.altAction()
            } else {
                root.clicked()
            }
        }
    }
}
