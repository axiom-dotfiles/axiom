pragma Singleton
import QtQuick
import qs.services

// Reader for the Popouts section: behaviour shared by bar popouts and
// screen-edge popouts. (Named PopoutConfig because `Popouts` is the bar
// popout wrapper type.)
QtObject {
  readonly property var _c: ConfigManager.config.Popouts

  readonly property int openDelay: _c.openDelay
  readonly property int dismissDelay: _c.dismissDelay
  readonly property int edgeTriggerSize: _c.edgeTriggerSize
}
