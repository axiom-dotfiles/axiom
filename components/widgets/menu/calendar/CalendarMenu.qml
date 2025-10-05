// components/Calendar/CalendarMenu.qml
import QtQuick
import QtQuick.Layouts

import qs.config
import qs.components.reusable

StyledContainer {
    ColumnLayout {
        anchors.fill: parent
        spacing: Widget.spacing

        Calendar {
            width: parent.width
        }

        /*
        StyledSeparator {
            Layout.fillWidth: true
        }

        StyledText {
            text: "Upcoming Events"
            font.bold: true
        }
        */
    }
}
