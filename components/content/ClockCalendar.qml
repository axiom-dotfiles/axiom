pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.config
import qs.components.methods
import qs.components.reusable
import qs.components.content.base
import qs.components.content.parts.calendar
import qs.services

// A clock with the date, plus a month calendar where it fits (beside the
// clock in wide slots, or where it only fits that way); a wide strip puts
// the date beside the time. Arrows page through months. With `showEvents`
// (never on the lock screen or the login screen: they're private) days
// with events get their calendars' dots, and a click shows the day's
// events in the clock's place (the whole card when the calendar is under
// the clock), where they open in the editor.
// properties: { use24Hour, showSeconds, showEvents }
Card {
  id: root

  readonly property bool showEvents: (root.properties.showEvents ?? true) && root.host?.kind !== "lockscreen" && root.host?.kind !== "greeter" && !Paths.greeter
  // The day shown in the clock's place, "" for the clock
  property string openDay: ""
  onShowEventsChanged: {
    if (root.showEvents)
      CalendarManager.acquire(root);
    else
      CalendarManager.release(root);
  }
  Component.onCompleted: {
    if (root.showEvents)
      CalendarManager.acquire(root);
  }
  Component.onDestruction: CalendarManager.release(root)

  // Calendar sizing: day cells close to square, never taller than they
  // are wide, and the whole grid capped so large slots keep a big clock
  readonly property real headerHeight: Appearance.fontSize * 1.8
  readonly property real weekdayHeight: Appearance.fontSize * 1.6
  // The smallest calendar (six weeks of the smallest cells), and whether
  // it fits under the clock or beside it
  readonly property real calendarMinHeight: root.headerHeight + root.weekdayHeight + Appearance.fontSize * 1.4 * 6
  readonly property real calendarMinWidth: Appearance.fontSize * 12
  readonly property bool fitsUnder: root.innerHeight >= root.clockMinHeight + Widget.spacing + root.calendarMinHeight && root.innerWidth >= root.calendarMinWidth
  readonly property bool fitsBeside: root.innerHeight >= root.calendarMinHeight && root.innerWidth >= root.calendarMinWidth + root.pad + Appearance.fontSize * 8
  readonly property bool showCalendar: !root.compact && (root.fitsUnder || root.fitsBeside)
  readonly property bool sideBySide: root.showCalendar && root.fitsBeside && (root.shape === "horizontal" || !root.fitsUnder)
  // A wide strip: the date beside the time
  readonly property bool clockRow: !root.showCalendar && root.innerWidth > root.innerHeight * 2.5
  readonly property real calendarWidth: Math.min(root.sideBySide ? (root.innerWidth - root.pad) / 2 : root.innerWidth, Appearance.fontSize * 32)
  readonly property real clockMinHeight: Appearance.fontSize * 5
  readonly property real cellHeight: Math.max(Appearance.fontSize * 1.4, Math.min(root.calendarWidth / 7 * 0.85, ((root.sideBySide ? root.innerHeight : root.innerHeight - root.clockMinHeight - Widget.spacing) - root.headerHeight - root.weekdayHeight) / 6))
  readonly property real calendarHeight: root.headerHeight + root.weekdayHeight + root.cellHeight * 6
  readonly property date now: clock.date
  // The language's time format (e.g. 午後 3:05 in Japanese), seconds added after the minutes
  readonly property string timeFormat: I18n.dateFormat(root.properties.use24Hour ? "time24" : "time12").replace("mm", root.properties.showSeconds ? "mm:ss" : "mm")

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

    // Clock: as big as its area allows (or the day opened from the
    // calendar beside it)
    Item {
      visible: root.openDay === "" || root.sideBySide
      Layout.fillWidth: true
      Layout.fillHeight: true
      Layout.preferredWidth: root.sideBySide ? root.innerWidth - root.calendarWidth - root.pad : root.innerWidth

      DayPane {
        anchors.fill: parent
        visible: root.openDay !== ""
        dayKey: root.openDay || CalendarEvents.dayKey(root.now)
        closable: true
        onClosed: root.openDay = ""
      }

      GridLayout {
        id: clockBox
        visible: root.openDay === ""
        anchors.centerIn: parent
        width: parent.width
        columns: root.clockRow ? 2 : 1
        columnSpacing: root.pad
        rowSpacing: 0
        StyledText {
          Layout.fillWidth: true
          // No taller than the digits fitted to the width need, so the date
          // stays right under them (beside them in a row: the strip's height)
          Layout.preferredHeight: root.clockRow ? clockBox.parent.height : Math.min(clockBox.width * 0.42, Math.max(Appearance.fontSize * 2, clockBox.parent.height - dateText.height) * 0.8)
          horizontalAlignment: root.clockRow ? Text.AlignRight : Text.AlignHCenter
          verticalAlignment: Text.AlignVCenter
          fontSizeMode: Text.Fit
          minimumPixelSize: Math.min(Appearance.fontSize, 8)
          textSize: Appearance.fontSize * 9
          text: I18n.formatDate(root.now, root.timeFormat)
          font.bold: true
        }
        StyledText {
          id: dateText
          visible: clockBox.parent.height >= Appearance.fontSize * 3 || root.clockRow
          Layout.fillWidth: !root.clockRow
          Layout.maximumWidth: root.clockRow ? clockBox.width * 0.45 : -1
          horizontalAlignment: root.clockRow ? Text.AlignLeft : Text.AlignHCenter
          elide: Text.ElideRight
          text: I18n.formatDate(root.now, I18n.dateFormat(root.compact ? "shortDate" : "longDate"))
          textSize: root.compact ? Appearance.fontSize - 2 : Appearance.fontSize
          opacity: 0.7
        }
      }
    }

    // Calendar
    MonthGrid {
      visible: root.showCalendar && (root.openDay === "" || root.sideBySide)
      Layout.alignment: Qt.AlignCenter
      Layout.preferredWidth: root.calendarWidth
      Layout.maximumWidth: root.calendarWidth
      Layout.preferredHeight: root.calendarHeight
      Layout.maximumHeight: root.calendarHeight
      headerHeight: root.headerHeight
      weekdayHeight: root.weekdayHeight
      showEvents: root.showEvents
      selectedKey: root.openDay
      onDaySelected: key => {
        if (root.showEvents)
          root.openDay = root.openDay === key ? "" : key;
      }
    }
  }

  // The opened day over the whole card, when the calendar is under the clock
  DayPane {
    anchors.fill: parent
    anchors.margins: root.pad
    visible: root.openDay !== "" && !root.sideBySide
    dayKey: root.openDay || CalendarEvents.dayKey(root.now)
    closable: true
    onClosed: root.openDay = ""
  }
}
