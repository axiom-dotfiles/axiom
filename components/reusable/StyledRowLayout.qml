// qs/components/reusable/StyledRowLayout.qml
pragma ComponentBehavior: Bound

import QtQuick.Layouts

import qs.config

RowLayout {
    property int layoutSpacing: Widget.spacing
    spacing: layoutSpacing
}
