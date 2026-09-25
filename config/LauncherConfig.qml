pragma Singleton
import QtQuick
import qs.services

// Reader for the Launcher section (the search launcher). Named
// LauncherConfig because `Launcher` is the surface type.
QtObject {
  readonly property var _c: ConfigManager.config.Launcher

  // "general" | "primaryBar" | "focused" | "all" (see General.screensFor)
  readonly property string monitors: _c.monitors
  // "center" | "upper" | "top" | "bottom"
  readonly property string position: _c.position
  // On the top or bottom edge, as an edge popout
  readonly property bool attached: position === "top" || position === "bottom"
  // Search field under the results
  readonly property bool reverse: _c.reverse
  readonly property int width: _c.width
  readonly property int maxResults: _c.maxResults
  readonly property int iconSize: _c.iconSize
  // Dim the screen behind it
  readonly property bool showBackdrop: _c.showBackdrop
  // 0-1 opacity of the backdrop
  readonly property real backdrop: _c.backdrop / 100
  readonly property bool showDescriptions: _c.showDescriptions
  readonly property bool showRecent: _c.showRecent
  readonly property bool showHint: _c.showHint
  // Desktop entry ids never listed
  readonly property var hiddenApps: _c.hiddenApps

  // Providers
  readonly property bool windows: _c.windows
  readonly property bool calculator: _c.calculator
  readonly property bool commands: _c.commands
  readonly property bool runCommands: _c.runCommands
  readonly property bool webSearch: _c.webSearch
  // "@question" asks the overlay's chat
  readonly property bool chat: _c.chat
  readonly property string terminal: _c.terminal
  // With {} where the terms go
  readonly property string searchEngine: _c.searchEngine
}
