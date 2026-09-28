pragma Singleton
import QtQuick
import qs.services

// Reader for the NightLight section: warmer colors through hyprsunset or
// wlsunset, run by NightLightManager.
QtObject {
  id: root

  readonly property var _c: ConfigManager.config.NightLight

  readonly property bool schedule: _c.schedule
  // "HH:MM", on from startAt until endAt (past midnight when it's earlier)
  readonly property string startAt: _c.startAt
  readonly property string endAt: _c.endAt
  // Kelvin
  readonly property int temperature: _c.temperature
  // Percent; 100 leaves it alone
  readonly property int gamma: _c.gamma
}
