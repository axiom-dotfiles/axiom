pragma Singleton
import QtQuick
import qs.services

// Reader for the Apps section: the apps axiom opens (keybinds, the
// launcher's terminal apps and Shift+Enter commands)
QtObject {
  readonly property var _c: ConfigManager.config.Apps

  readonly property string terminal: _c.terminal
  // Empty is the system default (xdg-open / xdg-settings)
  readonly property string fileManager: _c.fileManager
  readonly property string browser: _c.browser
  // What a bind (or the onboarder) runs to open each
  readonly property string terminalCommand: terminal.trim() || "xdg-terminal-exec"
  readonly property string fileManagerCommand: fileManager.trim() || 'xdg-open "$HOME"'
  readonly property string browserCommand: browser.trim() || 'b=$(xdg-settings get default-web-browser 2>/dev/null) && [ -n "$b" ] && gtk-launch "${b%.desktop}" || xdg-open https://'
}
