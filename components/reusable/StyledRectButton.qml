// qs/components/reusable/StyledIconButton.qml
pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import qs.config
import qs.components.reusable

Rectangle {
    id: button
    
    property string iconText: ""
    property int iconSize: Appearance.fontSize
    property string tooltipText: ""
    property color iconColor: Theme.foreground

    property color hoverColor: Theme.backgroundHighlight
    property color pressColor: Theme.backgroundAlt

    property color backgroundColor: "transparent"
    property color borderColor: "transparent"
    property int borderWidth: Appearance.borderWidth
    property real borderRadius: Appearance.borderRadius

    Layout.fillHeight: true
    Layout.fillWidth: true
    Layout.alignment: Qt.AlignHCenter | Qt.AlignVCenter

}
