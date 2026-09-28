pragma Singleton
import QtQuick
import qs.services

// Reader for the Idle section: hypridle, run by HypridleManager. Timeouts
// are seconds, 0 turning that step off.
QtObject {
  id: root

  readonly property var _c: ConfigManager.config.Idle
  // The whole section, so HypridleManager re-renders on any change
  readonly property string _json: JSON.stringify(_c)

  readonly property bool enabled: _c.enabled
  readonly property int dimTimeout: _c.dimTimeout
  // "to": down to dimLevel%; "by": dimBy% off each screen's brightness
  readonly property string dimMode: _c.dimMode
  readonly property int dimLevel: _c.dimLevel
  readonly property int dimBy: _c.dimBy
  readonly property int lockTimeout: _c.lockTimeout
  readonly property int screenOffTimeout: _c.screenOffTimeout
  readonly property int suspendTimeout: _c.suspendTimeout
  readonly property bool lockBeforeSleep: _c.lockBeforeSleep
  readonly property bool screenOnAfterSleep: _c.screenOnAfterSleep
  readonly property bool respectInhibitors: _c.respectInhibitors
  // [{ enabled, timeout, onTimeout, onResume }]
  readonly property var listeners: _c.listeners
}
