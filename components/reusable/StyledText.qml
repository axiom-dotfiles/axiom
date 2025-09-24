// qs/components/reusable/StyledText.qml
pragma ComponentBehavior: Bound

import QtQuick

import qs.config

Text {
    property alias text: control.text
    property color textColor: Theme.foreground
    property string textFamily: Appearance.fontFamily
    property int textSize: Appearance.fontSize
    property alias horizontalAlignment: control.horizontalAlignment
    property alias verticalAlignment: control.verticalAlignment
    property alias elide: control.elide

    id: control
    color: textColor
    font.family: textFamily
    font.pixelSize: textSize
}
