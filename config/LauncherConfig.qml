pragma Singleton
import QtQuick
import qs.services

// Reader for the Launcher section (the search launcher). Named
// LauncherConfig because `Launcher` is the surface type.
QtObject {
  readonly property var _c: ConfigManager.config.Launcher

  // "general" | "primary" | "focused" | "all" (see General.screensFor)
  readonly property string monitors: _c.monitors
  // Placed as docks and OSDs are: a Bar.Location, its centre's position
  // along it (0-1), and whether it floats off the edge (a FloatingPopout,
  // `distance` 0-0.5 across the free screen: 0.5 centres it) or grows out
  // of it (an EdgePopout)
  readonly property int edge: Bar.getLocationFromString(_c.edge)
  readonly property real position: _c.position / 100
  readonly property bool detached: _c.detached
  readonly property real distance: _c.distance / 100
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
  // ":" searches the clipboard history (ClipboardManager)
  readonly property bool clipboard: _c.clipboard
  // "axiom" | "cliphist"
  readonly property string clipboardSource: _c.clipboardSource
  readonly property int clipboardMaxEntries: _c.clipboardMaxEntries
  // ";" searches emoji (EmojiManager)
  readonly property bool emoji: _c.emoji
  // With {} where the terms go
  readonly property string searchEngine: _c.searchEngine
}
