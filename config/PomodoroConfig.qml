pragma Singleton
import QtQuick
import qs.services

// Reader for the Pomodoro section: the session and break lengths every
// pomodoro widget and module runs (see PomodoroManager).
QtObject {
  id: root

  readonly property var _c: ConfigManager.config.Pomodoro

  // Minutes
  readonly property int workMinutes: _c.workMinutes
  readonly property int shortBreakMinutes: _c.shortBreakMinutes
  readonly property int longBreakMinutes: _c.longBreakMinutes
  // Focus sessions before a long break
  readonly property int longBreakEvery: _c.longBreakEvery
  readonly property bool autoStartBreaks: _c.autoStartBreaks
  readonly property bool autoStartWork: _c.autoStartWork
  readonly property bool notify: _c.notify
  // The lengths as PomodoroCycle takes them
  readonly property var settings: ({
      "workMinutes": root.workMinutes,
      "shortBreakMinutes": root.shortBreakMinutes,
      "longBreakMinutes": root.longBreakMinutes,
      "longBreakEvery": root.longBreakEvery
    })
}
