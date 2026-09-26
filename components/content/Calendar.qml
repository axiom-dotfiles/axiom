pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Quickshell

import qs.config
import qs.components.methods
import qs.components.reusable
import qs.components.content.base

Panel {
  id: root

  // Month currently on display. Day component is ignored/normalized to 1st.
  property var viewDate: new Date()

  margins: 20
  spacing: root.sectionSpacing
  readonly property int cellSize: 30
  readonly property int cellSpacing: 4
  readonly property int headerHeight: 26
  readonly property int weekdayHeight: 18
  readonly property int sectionSpacing: 10
  readonly property int footerHeight: 32

  readonly property int gridWidth: cellSize * 7 + cellSpacing * 6
  readonly property int gridHeight: cellSize * 6 + cellSpacing * 5

  implicitWidth: gridWidth + margins * 2
  implicitHeight: margins * 2 + headerHeight + sectionSpacing + weekdayHeight + 4 + gridHeight + sectionSpacing + footerHeight

  SystemClock {
    id: todayClock
    precision: SystemClock.Hours
  }

  // Weeks start on the language's first day; narrow names in that language
  readonly property int firstDay: I18n.locale.firstDayOfWeek % 7
  readonly property var weekdayLabels: [0, 1, 2, 3, 4, 5, 6].map(i => I18n.locale.dayName((root.firstDay + i) % 7, Locale.NarrowFormat))

  // A string, so the grid is only rebuilt when the day changes
  readonly property string today: todayClock.date.toDateString()
  readonly property var gridDays: Utils.monthGrid(viewDate.getFullYear(), viewDate.getMonth(), root.firstDay, root.today)

  function shiftMonth(delta) {
    viewDate = new Date(viewDate.getFullYear(), viewDate.getMonth() + delta, 1);
  }

  function goToToday() {
    viewDate = new Date(todayClock.date.getFullYear(), todayClock.date.getMonth(), 1);
  }

  // --- Header: month navigation ---
  RowLayout {
    Layout.fillWidth: true
    Layout.preferredHeight: root.headerHeight
    spacing: 8

    StyledIconButton {
      Layout.preferredWidth: root.headerHeight
      Layout.preferredHeight: root.headerHeight

      iconText: "‹"
      iconSize: root.headerHeight * 0.5
      borderRadius: root.headerHeight / 2
      iconColor: Theme.foregroundAlt
      backgroundColor: Theme.backgroundAlt
      hoverColor: Theme.accentAlt
      pressColor: Theme.accentAlt

      onClicked: root.shiftMonth(-1)
    }

    StyledText {
      Layout.fillWidth: true
      horizontalAlignment: Text.AlignHCenter
      text: I18n.formatDate(root.viewDate, I18n.dateFormat("monthYear"))
      textColor: Theme.accent
      textSize: Appearance.fontSize * 1.05
      font.bold: true
    }

    StyledIconButton {
      Layout.preferredWidth: root.headerHeight
      Layout.preferredHeight: root.headerHeight

      iconText: "›"
      iconSize: root.headerHeight * 0.5
      borderRadius: root.headerHeight / 2
      iconColor: Theme.foregroundAlt
      backgroundColor: Theme.backgroundAlt
      hoverColor: Theme.accentAlt
      pressColor: Theme.accentAlt

      onClicked: root.shiftMonth(1)
    }
  }

  // --- Weekday labels ---
  RowLayout {
    Layout.fillWidth: true
    Layout.preferredHeight: root.weekdayHeight
    spacing: root.cellSpacing

    Repeater {
      model: root.weekdayLabels

      StyledText {
        required property string modelData

        Layout.preferredWidth: root.cellSize
        horizontalAlignment: Text.AlignHCenter
        text: modelData
        textColor: Theme.foregroundAlt
        textSize: Appearance.fontSize * 0.85
        opacity: 0.7
      }
    }
  }

  // --- Day grid ---
  GridLayout {
    Layout.preferredWidth: root.gridWidth
    Layout.preferredHeight: root.gridHeight
    columns: 7
    rows: 6
    columnSpacing: root.cellSpacing
    rowSpacing: root.cellSpacing

    Repeater {
      model: root.gridDays

      Rectangle {
        id: dayCell
        required property var modelData

        Layout.preferredWidth: root.cellSize
        Layout.preferredHeight: root.cellSize
        radius: root.cellSize / 2

        color: modelData.isToday ? Theme.accent : (dayMouseArea.containsMouse && modelData.inMonth ? Theme.backgroundHighlight : "transparent")

        Behavior on color {
          ColorAnimation {
            duration: Appearance.animFast
          }
        }

        StyledText {
          anchors.centerIn: parent
          text: dayCell.modelData.day
          textSize: Appearance.fontSize * 0.9
          textColor: dayCell.modelData.isToday ? Theme.background : (dayCell.modelData.inMonth ? Theme.foreground : Theme.foregroundInactive)
          opacity: dayCell.modelData.inMonth ? 1.0 : 0.5
        }

        MouseArea {
          id: dayMouseArea
          anchors.fill: parent
          hoverEnabled: true
          acceptedButtons: Qt.NoButton
        }
      }
    }
  }

  // --- Footer: today shortcut ---
  RowLayout {
    Layout.fillWidth: true
    Layout.preferredHeight: root.footerHeight
    spacing: 8

    StyledText {
      Layout.fillWidth: true
      text: I18n.formatDate(todayClock.date, I18n.dateFormat("fullDate"))
      textColor: Theme.foregroundAlt
      textSize: Appearance.fontSize * 0.8
      opacity: 0.8
      elide: Text.ElideRight
    }

    StyledTextButton {
      Layout.preferredHeight: root.footerHeight
      text: I18n.tr("Today")
      textPadding: 6
      onClicked: root.goToToday()
    }
  }
}
