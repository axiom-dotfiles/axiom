// components/Calendar/CalendarMenu.qml
import QtQuick
import QtQuick.Layouts

import qs.config
import qs.components.reusable

StyledContainer {
    Component.onCompleted: {
        console.log("CalendarMenu loaded");
    }
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
