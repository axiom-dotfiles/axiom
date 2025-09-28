// components/Calendar/Calendar.qml
import QtQuick
import QtQuick.Layouts

import qs.config
import qs.components.reusable

ColumnLayout {
    id: calendarRoot
    width: parent.width
    spacing: Widget.padding

    // --- Exposed Properties ---
    property date currentDate: new Date()

    // --- Internal Properties ---
    readonly property date today: new Date()
    property int selectedIndex: -1 // Used for keyboard navigation

    // --- Date Logic ---
    // Helper function to get the first day of the currently viewed month
    function getFirstDayOfMonth(date) {
        return new Date(date.getFullYear(), date.getMonth(), 1);
    }

    // The calendar grid needs to start on the Sunday of the week containing the 1st of the month.
    readonly property date firstDayInGrid: {
        let firstOfMonth = getFirstDayOfMonth(currentDate);
        // .getDay() returns 0 for Sunday, 1 for Monday, etc.
        let dayOfWeek = firstOfMonth.getDay();
        // Subtract that many days from the 1st to get the preceding Sunday.
        let startDate = new Date(firstOfMonth);
        startDate.setDate(firstOfMonth.getDate() - dayOfWeek);
        return startDate;
    }

    // --- Header: Month Navigation ---
    RowLayout {
        width: parent.width

        StyledIconButton {
            text: "<"
            onClicked: {
                let newDate = new Date(currentDate);
                newDate.setMonth(newDate.getMonth() - 1);
                currentDate = newDate;
            }
        }

        StyledText {
            Layout.fillWidth: true
            text: currentDate.toLocaleString(Qt.locale(), "MMMM yyyy")
            font.bold: true
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
        }

        StyledIconButton {
            text: ">"
            onClicked: {
                let newDate = new Date(currentDate);
                newDate.setMonth(newDate.getMonth() + 1);
                currentDate = newDate;
            }
        }
    }

    // --- Day of Week Labels ---
    GridLayout {
        width: parent.width
        columns: 7

        Repeater {
            model: ["S", "M", "T", "W", "T", "F", "S"] // Starting with Sunday
            delegate: StyledText {
                text: modelData
                horizontalAlignment: Text.AlignHCenter
                textColor: Theme.foregroundAlt
                Layout.fillWidth: true
                padding: Widget.padding / 2
            }
        }
    }

    // --- Calendar Day Grid ---
    GridLayout {
        id: daysGrid
        width: parent.width
        columns: 7
        focus: true // Allow this grid to receive key events

        Repeater {
            model: 42 // 6 rows * 7 columns = 42 cells, covers all month layouts

            delegate: CalendarDay {
                id: dayDelegate

                // Calculate the date for this specific cell
                readonly property date cellDate: {
                    let date = new Date(calendarRoot.firstDayInGrid);
                    date.setDate(date.getDate() + index);
                    return date;
                }

                // Pass properties to the day component
                dayDate: cellDate
                isCurrentMonth: cellDate.getMonth() === calendarRoot.currentDate.getMonth()
                isToday: cellDate.toDateString() === calendarRoot.today.toDateString()
                isSelected: calendarRoot.selectedIndex === index
                Layout.fillWidth: true

                Component.onCompleted: {
                    // When the calendar loads, select today's date
                    if (isToday) {
                        calendarRoot.selectedIndex = index;
                    }
                }
                
                // Allow clicking to select a day
                MouseArea {
                    anchors.fill: parent
                    onClicked: {
                        calendarRoot.selectedIndex = index;
                        daysGrid.forceActiveFocus(); // Ensure keys work after a click
                    }
                }
            }
        }

        // Handle arrow key navigation
        Keys.onPressed: (event) => {
            if (selectedIndex === -1) {
                // If nothing is selected, select the first day of the month
                selectedIndex = new Date(currentDate).getDate() - 1 + firstDayInGrid.getDay();
                return;
            }

            let newIndex = selectedIndex;
            if (event.key === Qt.Key_Left) newIndex--;
            else if (event.key === Qt.Key_Right) newIndex++;
            else if (event.key === Qt.Key_Up) newIndex -= 7;
            else if (event.key === Qt.Key_Down) newIndex += 7;

            if (newIndex >= 0 && newIndex < 42) {
                selectedIndex = newIndex;
                event.accepted = true; // We handled this key press
            }
        }
    }
}
