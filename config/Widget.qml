pragma Singleton
import QtQuick
import qs.services

// Reader for the Widget section: sizing for panels, cards, popouts and
// controls, and the card size every module grid starts from. Bars size
// their own widgets (Bar.enrichBarConfig).
QtObject {
  readonly property var _c: ConfigManager.config.Widget

  // The Interface scale, as a factor: text (Appearance.fontSize) and the
  // sizes below grow with it
  readonly property real scale: _c.scale / 100
  // How big module cards are, in % of what fills the overlay
  // (OverlayConfig.cardUnitOn)
  readonly property int cardSize: _c.cardSize
  // "compact" | "normal" | "roomy"
  readonly property string density: _c.density

  // Each density's control height, padding, spacing and card padding (px,
  // at 100 % scale)
  readonly property var _densities: ({
      "compact": {
        "height": 26,
        "padding": 7,
        "spacing": 3,
        "card": 9
      },
      "normal": {
        "height": 30,
        "padding": 10,
        "spacing": 4,
        "card": 12
      },
      "roomy": {
        "height": 36,
        "padding": 14,
        "spacing": 6,
        "card": 16
      }
    })
  readonly property var _density: _densities[density]

  // Height of buttons, fields and other controls
  readonly property int height: Math.round(_density.height * scale)
  // Inner padding of panels, cards and controls
  readonly property int padding: Math.round(_density.padding * scale)
  // Gap between items inside panels, cards and controls
  readonly property int spacing: Math.round(_density.spacing * scale)
  // A module card's padding (OverlayConfig.cardPad)
  readonly property int cardPadding: Math.round(_density.card * scale)
  // Corners of what sits inside something (cards, controls, rows, bar
  // widgets); outer edges use Appearance.borderRadius
  readonly property int radius: _c.overrideRadius ? _c.radius : Appearance.borderRadius
}
