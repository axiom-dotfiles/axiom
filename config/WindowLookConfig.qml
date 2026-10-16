pragma Singleton
import QtQuick
import qs.services

// Reader for the WindowLook section: settings that make windows match
// axiom ({ borders, activeColor, shape, matchShell, gaps, blur…,
// opacity… }), applied by the compositor's backend (on Hyprland,
// HyprlandConfigManager's look layer) through CompositorLayer.look. Named
// WindowLookConfig as the section is a whole object.
QtObject {
  id: root

  readonly property var _c: ConfigManager.config.WindowLook

  // Goes through a string so a reload that leaves it unchanged doesn't
  // apply it again
  readonly property string _lookJson: JSON.stringify(_c)
  readonly property var look: JSON.parse(_lookJson)

  // The border colors: the ones picked, else the theme's
  readonly property color activeBorder: _c.activeColor ? Theme.resolveColor(_c.activeColor) : Theme.borderFocus
  readonly property color inactiveBorder: _c.inactiveColor ? Theme.resolveColor(_c.inactiveColor) : Theme.border
  // The shape: axiom's (Look & Feel → Shape) while it matches it, else its own
  readonly property int borderWidth: _c.matchShell ? Appearance.borderWidth : _c.borderSize
  readonly property int radius: _c.matchShell ? Appearance.borderRadius : _c.rounding
}
