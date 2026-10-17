pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell

import qs.config

/*
 * The cursor theme as XCursor readers get it (the compositor's
 * xcursor-theme, XCURSOR_THEME, GTK's cursor-theme). A theme naming its
 * cursors only the X11 way (left_ptr, not default) and inheriting nothing
 * shows the "default" theme's cursors (often Adwaita's) for the standard
 * names it lacks, the arrow among them. So while the Input section's
 * cursor part is on, scripts/cursor_theme.py makes a companion theme
 * (axiom-cursor in $XDG_DATA_HOME/icons/) inheriting it, with those names
 * linked to its own cursors, and sets GTK's cursor-theme and cursor-size
 * to what XCursor readers get. CompositorConfigManager hands that name on
 * (CompositorLayer.input's `xcursor`); Hyprland's setcursor and the greeter
 * keep the theme's own (docs/dev/compositor/config-modes.md).
 */
Singleton {
  id: root

  // The name XCursor readers get for the theme set now: the companion
  // theme where it fills names in, else the theme's own; "" while the
  // cursor part is off or until it's known
  readonly property string xcursorTheme: _resolved.theme === _wanted ? _resolved.name : ""
  // Whether xcursorTheme has been known once (CompositorConfigManager
  // waits for it at start, so it writes the name once)
  readonly property bool ready: _wanted === "" || _resolvedOnce || Paths.greeter
  // The companion theme's name (left out of the themes to pick)
  readonly property string companionName: "axiom-cursor"

  readonly property string _wanted: InputConfig.input.cursor ? InputConfig.cursorTheme : ""
  readonly property int _size: InputConfig.input.cursorSize
  property var _resolved: ({
      "theme": "",
      "name": ""
    })
  property bool _resolvedOnce: false

  on_WantedChanged: _resolve()
  on_SizeChanged: _resolve()
  Component.onCompleted: _resolve()

  function _resolve() {
    // The greeter writes nothing (services/AGENTS.md)
    const theme = root._wanted;
    if (theme === "" || Paths.greeter)
      return;
    CommandManager.run([Paths.scriptsPath + "cursor_theme.py", theme, "--size", String(root._size), "--gsettings"], (code, out, err) => {
      let name = theme;
      if (code === 0) {
        try {
          name = JSON.parse(out).theme || theme;
        } catch (e) {}
      } else {
        console.warn("[CursorThemeManager] cursor_theme.py:", String(err).trim());
      }
      if (theme !== root._wanted)
        return;
      root._resolved = {
        "theme": theme,
        "name": name
      };
      root._resolvedOnce = true;
    });
  }
}
