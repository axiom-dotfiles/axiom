pragma Singleton
import QtQuick
import qs.services

// Reader for the OSD section (the volume, microphone and brightness
// on-screen display). Named
// OSDConfig because `OSD` is the module type.
QtObject {
  readonly property var _c: ConfigManager.config.OSD

  readonly property bool enabled: _c.enabled
  // "general" | "primaryBar" | "focused" | "all" (see General.screensFor)
  readonly property string monitors: _c.monitors
  // A Bar.Location
  readonly property int edge: Bar.getLocationFromString(_c.edge)
  // 0-1 along the edge, as EdgePopout.position expects
  readonly property real position: _c.position / 100
  readonly property bool vertical: _c.orientation === "Vertical"
  // Bars in one line along the edge, whatever their orientation
  readonly property bool alongEdge: _c.alongEdge
  // The edge trigger strip also opens it
  readonly property bool openOnHover: _c.openOnHover
  readonly property int timeout: _c.timeout
  // [{ type, app, icon, showOsd }]; type is master | other | microphone |
  // brightness | app. Goes through a string so a reload that leaves the
  // list unchanged doesn't rebuild the OSD's bars.
  readonly property string _barsJson: JSON.stringify(_c.bars)
  readonly property var bars: JSON.parse(_barsJson)
  // The streams the App bars match, which the Other apps bar skips
  readonly property var excludedApps: bars.filter(bar => bar.type === "app" && bar.app !== "").map(bar => bar.app)
}
