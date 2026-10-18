pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import qs.config
import qs.services
import qs.components.reusable

// The pomodoro timer (PomodoroManager), for the Pomodoro popout and module
// and the Focus module: a ring with the time left and the phase, a dot per
// session until the long break, stop / start-pause / skip, and (with
// `showTask`) the todo the sessions are for. `horizontal` puts the ring
// beside the rest (a wide, short card). Its owner acquires the manager.
GridLayout {
  id: root

  property bool showTask: true
  property bool horizontal: false
  property real dialSize: Appearance.fontSize * 8

  readonly property color phaseColor: PomodoroManager.isBreak ? Theme.accentAlt : Theme.accent
  // Sessions done towards the next long break (all of them during it)
  readonly property int towardsLong: PomodoroManager.phase === "long" ? PomodoroConfig.longBreakEvery : PomodoroManager.completed % PomodoroConfig.longBreakEvery

  columns: root.horizontal ? 2 : 1
  columnSpacing: Widget.spacing * 2
  rowSpacing: Widget.spacing

  Item {
    Layout.alignment: Qt.AlignHCenter | Qt.AlignVCenter
    Layout.preferredWidth: root.dialSize
    Layout.preferredHeight: root.dialSize

    PercentageCircle {
      anchors.fill: parent
      percentage: PomodoroManager.progress * 100
      iconText: ""
      fillColor: root.phaseColor
    }

    ColumnLayout {
      anchors.centerIn: parent
      spacing: 0

      StyledText {
        Layout.alignment: Qt.AlignHCenter
        text: PomodoroManager.remainingText
        textSize: Math.max(Appearance.fontSize, Math.round(root.dialSize * 0.2))
        font.bold: true
        textColor: PomodoroManager.running ? Theme.foreground : Theme.foregroundAlt
      }
      StyledText {
        Layout.alignment: Qt.AlignHCenter
        text: PomodoroManager.idle || PomodoroManager.running ? PomodoroManager.phaseLabel : I18n.tr("Paused")
        textSize: Appearance.fontSize - 2
        textColor: root.phaseColor
      }
    }
  }

  ColumnLayout {
    Layout.fillWidth: true
    Layout.alignment: Qt.AlignVCenter
    spacing: Widget.spacing

    Row {
      Layout.alignment: Qt.AlignHCenter
      spacing: Widget.spacing / 2

      Repeater {
        model: PomodoroConfig.longBreakEvery
        Rectangle {
          required property int index
          width: Appearance.fontSize * 0.6
          height: width
          radius: width / 2
          color: index < root.towardsLong ? Theme.accent : Theme.backgroundHighlight
        }
      }
    }

    RowLayout {
      Layout.alignment: Qt.AlignHCenter
      spacing: Widget.spacing

      FlatIconButton {
        size: Math.round(Appearance.fontSize * 2)
        iconText: "stop"
        enabled: !PomodoroManager.idle
        tooltipText: I18n.tr("Stop")
        onClicked: PomodoroManager.stop()
      }
      FlatIconButton {
        size: Math.round(Appearance.fontSize * 2.6)
        iconText: PomodoroManager.running ? "pause" : "play_arrow"
        iconColor: root.phaseColor
        tooltipText: PomodoroManager.running ? I18n.tr("Pause") : I18n.tr("Start")
        onClicked: PomodoroManager.toggle()
      }
      FlatIconButton {
        size: Math.round(Appearance.fontSize * 2)
        iconText: "skip_next"
        tooltipText: I18n.tr("Skip to the next phase")
        onClicked: PomodoroManager.skip()
      }
    }

    StyledComboEntry {
      visible: root.showTask
      Layout.fillWidth: true
      Layout.preferredHeight: Widget.height
      icon: "checklist"
      options: [
        {
          "value": "",
          "label": I18n.tr("No task")
        }
      ].concat(TodoManager.shownItems.filter(item => !item.done).map(item => ({
            "value": item.uid,
            "label": item.summary
          })))
      value: PomodoroManager.todoText !== "" ? PomodoroManager.todoUid : ""
      onPicked: value => PomodoroManager.setTodo(value)
    }
  }
}
