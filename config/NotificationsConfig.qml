pragma Singleton
import QtQuick
import qs.services

// Reader for the Notifications section (where toasts appear). Named
// NotificationsConfig because `Notifications` is a surface, module and bar
// widget type.
QtObject {
  readonly property var _c: ConfigManager.config.Notifications

  // "topLeft" | "topRight" | "bottomLeft" | "bottomRight"
  readonly property string position: _c.position
  readonly property bool top: position === "topLeft" || position === "topRight"
  readonly property bool left: position === "topLeft" || position === "bottomLeft"

  // Gaps from the work area's edges, per side (only the corner's two apply)
  readonly property bool evenGaps: _c.evenGaps
  readonly property int gapTop: evenGaps ? _c.gap : _c.gapTop
  readonly property int gapBottom: evenGaps ? _c.gap : _c.gapBottom
  readonly property int gapLeft: evenGaps ? _c.gap : _c.gapLeft
  readonly property int gapRight: evenGaps ? _c.gap : _c.gapRight
}
