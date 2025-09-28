// components/Calendar/CalendarDay.qml
import QtQuick
import QtQuick.Controls

import qs.config
import qs.components.reusable


StyledContainer {
    id: dayRoot

    // --- Exposed Properties ---
    property date dayDate
    property bool isCurrentMonth: false
    property bool isToday: false
    property bool isSelected: false

    // --- Configuration ---
    implicitWidth: 40
    implicitHeight: 40
    radius: Appearance.borderRadius
    
    // Highlight the selected day with a border, and the current day with a background
    border.width: isSelected ? Appearance.borderWidth * 2 : 0
    border.color: isSelected ? Theme.accentAlt : "transparent"
    containerColor: isToday ? Theme.accent : Theme.backgroundHighlight

    StyledText {
        anchors.centerIn: parent
        text: dayDate.getDate()
        font.bold: isToday
        
        // Dim the text for days not in the current month
        textColor: {
            if (isToday) {
                return Theme.background; // High contrast for the "today" background
            }
            if (isCurrentMonth) {
                return Theme.foreground;
            }
            return Theme.foregroundInactive;
        }
    }

    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        
        // Change background color on hover, unless it's the "today" cell
        onContainsMouseChanged: {
            if (!isToday && !isSelected) {
                dayRoot.containerColor = containsMouse ? Theme.backgroundHighlight : "transparent"
            }
        }
    }
}
