pragma Singleton
import QtQuick
import qs.services

// Reader for the Notifications section (toasts and the history). Named
// NotificationsConfig because `Notifications` is a surface, module and bar
// widget type.
QtObject {
  readonly property var _c: ConfigManager.config.Notifications

  // "general" | "primaryBar" | "focused" | "all" (see General.screensFor)
  readonly property string monitors: _c.monitors

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

  // Toasts
  readonly property int timeout: _c.timeout * 1000
  // Use a notification's own expireTimeout (0 = never) when it sets one
  readonly property bool appTimeouts: _c.appTimeouts
  readonly property bool criticalStays: _c.criticalStays
  readonly property int maxToasts: _c.maxToasts
  readonly property int width: _c.width
  readonly property bool quietFullscreen: _c.quietFullscreen

  // History
  readonly property bool clearOnFocus: _c.clearOnFocus
  readonly property bool removeOnClick: _c.removeOnClick
  readonly property bool closeRemoves: _c.closeRemoves
  readonly property int maxEntries: _c.maxEntries
  // 0 = keep forever
  readonly property int maxAgeDays: _c.maxAgeDays
}
