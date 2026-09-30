pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.config
import qs.components.methods
import qs.components.reusable
import qs.components.content.base

// A clock with the date, plus a month calendar when there's room (a card
// or more; beside the clock in wide slots). Arrows page through months.
// properties: { use24h, showSeconds }
Card {
  id: root

  readonly property bool showCalendar: !root.compact && root.rows >= 2
  readonly property bool sideBySide: root.showCalendar && root.shape === "horizontal"

  // Calendar sizing: day cells close to square, never taller than they
  // are wide, and the whole grid capped so large slots keep a big clock
  readonly property real bodyWidth: root.width - root.pad * 2
  readonly property real bodyHeight: root.height - root.pad * 2
  readonly property real headerHeight: Appearance.fontSize * 1.8
  readonly property real weekdayHeight: Appearance.fontSize * 1.6
  readonly property real calendarWidth: Math.min(root.sideBySide ? (root.bodyWidth - root.pad) / 2 : root.bodyWidth, Appearance.fontSize * 32)
  readonly property real clockMinHeight: Appearance.fontSize * 5
  readonly property real cellHeight: Math.max(Appearance.fontSize * 1.4, Math.min(root.calendarWidth / 7 * 0.85, ((root.sideBySide ? root.bodyHeight : root.bodyHeight - root.clockMinHeight - Widget.spacing) - root.headerHeight - root.weekdayHeight) / 6))
  readonly property real calendarHeight: root.headerHeight + root.weekdayHeight + root.cellHeight * 6
  readonly property date now: clock.date
  property int monthOffset: 0
  // Plain numbers and a date string: they only notify when the month or
  // day actually changes, not on every clock tick
  readonly property int shownYear: new Date(root.now.getFullYear(), root.now.getMonth() + root.monthOffset, 1).getFullYear()
  readonly property int shownMonthIndex: new Date(root.now.getFullYear(), root.now.getMonth() + root.monthOffset, 1).getMonth()
  readonly property date shownMonth: new Date(root.shownYear, root.shownMonthIndex, 1)
  readonly property string today: root.now.toDateString()
  readonly property int firstDay: I18n.locale.firstDayOfWeek % 7
  // The language's time format (e.g. 午後 3:05 in Japanese), seconds added after the minutes
  readonly property string timeFormat: I18n.dateFormat(root.properties.use24h ? "time24" : "time12").replace("mm", root.properties.showSeconds ? "mm:ss" : "mm")

  // 6 weeks of days for the shown month
  readonly property var days: Utils.monthGrid(root.shownYear, root.shownMonthIndex, root.firstDay, root.today)

  SystemClock {
    id: clock
    precision: root.properties.showSeconds ? SystemClock.Seconds : SystemClock.Minutes
  }

  GridLayout {
    anchors.fill: parent
    anchors.margins: root.pad
    columns: root.sideBySide ? 2 : 1
    columnSpacing: root.pad
    rowSpacing: Widget.spacing

    // Clock: as big as its area allows
    Item {
      Layout.fillWidth: true
      Layout.fillHeight: true
      Layout.preferredWidth: root.sideBySide ? root.bodyWidth - root.calendarWidth - root.pad : root.bodyWidth

      ColumnLayout {
        anchors.centerIn: parent
        width: parent.width
        spacing: 0
        StyledText {
          Layout.fillWidth: true
          // No taller than the digits fitted to the width need, so the date
          // stays right under them
          Layout.preferredHeight: Math.min(parent.width * 0.42, Math.max(Appearance.fontSize * 2, parent.parent.height - dateText.height) * 0.8)
          horizontalAlignment: Text.AlignHCenter
          verticalAlignment: Text.AlignVCenter
          fontSizeMode: Text.Fit
          minimumPixelSize: Appearance.fontSize
          textSize: Appearance.fontSize * 9
          text: I18n.formatDate(root.now, root.timeFormat)
          font.bold: true
        }
        StyledText {
          id: dateText
          Layout.fillWidth: true
          horizontalAlignment: Text.AlignHCenter
          elide: Text.ElideRight
          text: I18n.formatDate(root.now, I18n.dateFormat(root.compact ? "shortDate" : "longDate"))
          textSize: root.compact ? Appearance.fontSize - 2 : Appearance.fontSize
          opacity: 0.7
        }
      }
    }

    // Calendar
    ColumnLayout {
      visible: root.showCalendar
      Layout.alignment: Qt.AlignCenter
      Layout.preferredWidth: root.calendarWidth
      Layout.maximumWidth: root.calendarWidth
      Layout.preferredHeight: root.calendarHeight
      Layout.maximumHeight: root.calendarHeight
      spacing: 0

      RowLayout {
        Layout.fillWidth: true
        Layout.preferredHeight: root.headerHeight
        StyledText {
          Layout.fillWidth: true
          Layout.leftMargin: Widget.spacing / 2
          text: I18n.formatDate(root.shownMonth, I18n.dateFormat("monthYear"))
          font.bold: true
          MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: root.monthOffset = 0
          }
        }
        Repeater {
          model: [["chevron_left", -1], ["chevron_right", 1]]
          StyledIcon {
            required property var modelData
            Layout.preferredWidth: Appearance.fontSize * 1.6
            horizontalAlignment: Text.AlignHCenter
            text: modelData[0]
            textColor: Theme.accent
            textSize: Appearance.fontSize + 2
            MouseArea {
              anchors.fill: parent
              anchors.margins: -4
              cursorShape: Qt.PointingHandCursor
              onClicked: root.monthOffset += parent.modelData[1]
            }
          }
        }
      }

      GridLayout {
        Layout.fillWidth: true
        Layout.fillHeight: true
        columns: 7
        rowSpacing: 0
        columnSpacing: 0
        uniformCellWidths: true

        Repeater {
          model: 7
          StyledText {
            required property int index
            Layout.fillWidth: true
            Layout.preferredHeight: root.weekdayHeight
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            text: I18n.locale.dayName((root.firstDay + index) % 7, Locale.NarrowFormat)
            textSize: Appearance.fontSize - 2
            opacity: 0.6
          }
        }
        Repeater {
          model: root.days
          Item {
            id: cell
            required property var modelData
            Layout.fillWidth: true
            Layout.preferredHeight: root.cellHeight
            Rectangle {
              anchors.centerIn: parent
              width: Math.min(parent.width, parent.height) * 0.86
              height: width
              radius: width / 2
              color: cell.modelData.isToday ? Theme.accent : "transparent"
            }
            StyledText {
              anchors.centerIn: parent
              text: cell.modelData.day
              textColor: cell.modelData.isToday ? Theme.background : Theme.foreground
              font.bold: cell.modelData.isToday
              opacity: cell.modelData.inMonth ? 1 : 0.3
              textSize: Appearance.fontSize - 1
            }
          }
        }
      }
    }
  }
}
