pragma Singleton
import QtQuick
import qs.services

// Reader for the WindowLook section: settings that make windows match
// axiom ({ borders, activeColor, shape, matchShell, gaps, surfaceBlur…,
// blur…, shadow…, dim…, opacity… }), applied by the compositor's backend
// (its config writer's look layer) through CompositorLayer.look. Named
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
  // The windows' shadow: axiom's (Bar style's shadow, its color and size)
  // while it matches it, where off casts none; else its own
  readonly property bool _shadowMatched: _c.shadowMatchShell
  // Whether it stands in for axiom's own, a soft (blurred) shadow: as
  // axiom draws it where nothing caps it (Appearance.shadowAlphaMax keeps
  // the chrome's under the blur threshold; no blur reaches a window's)
  readonly property bool shadowSoft: _shadowMatched
  readonly property var _barLook: BarStyle.values
  readonly property bool shadowOn: _c.shadow && !(_shadowMatched && !_barLook.shadow)
  readonly property int shadowSize: _shadowMatched ? _barLook.shadowSize : _c.shadowSize
  // Its color: axiom's, the one picked, or none for the compositor's own
  readonly property bool shadowThemed: _shadowMatched || _c.shadowColor !== ""
  readonly property color shadowColor: _shadowMatched ? Bar.shadowBaseColor(_barLook) : shadowThemed ? Theme.resolveColor(_c.shadowColor) : "black"
  // (a picked color nearly opaque, as the compositors' own are)
  readonly property real shadowAlpha: _shadowMatched ? shadowColor.a : 0.93
  // How strong windows cast it (1 = as above), on top of its alpha
  readonly property real shadowStrength: _c.shadowStrength / 100
  // The shape: axiom's (Look & Feel → Shape) while it matches it, else its own
  readonly property int borderWidth: _c.matchShell ? Appearance.borderWidth : _c.borderSize
  readonly property int radius: _c.matchShell ? Appearance.borderRadius : _c.rounding
}
