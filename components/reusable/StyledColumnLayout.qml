// qs/components/reusable/StyledColumnLayout.qml
pragma ComponentBehavior: Bound

import QtQuick.Layouts

import qs.config

ColumnLayout {
    property int layoutSpacing: Widget.spacing
    spacing: layoutSpacing
}
