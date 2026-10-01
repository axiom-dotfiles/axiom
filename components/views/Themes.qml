pragma ComponentBehavior: Bound
import QtQuick

// The Themes page: wallpapers, the theme list and the palette's 16 colors.
// A view type with nothing to configure: Custom lays out the fixed
// modules below instead of the view's own.
Custom {
  id: root

  function at(x, y, w, h) {
    return {
      "x": x,
      "y": y,
      "w": w,
      "h": h
    };
  }

  // The 16 swatches as a 4 × 4 block of quarter cards right of the editor,
  // each 2 × 2 grid units
  function swatches() {
    const labels = ["bg0", "bg1", "bg2", "bg3", "fg4", "fg3", "fg2", "fg1", "error", "warning", "info", "success", "accentAlt", "accentHighlight", "accent", "decorative"];
    return labels.map((label, n) => ({
          "type": "ColorSwatch",
          "properties": {
            "color": "base0" + n.toString(16).toUpperCase(),
            "label": label
          },
          // Four colors per card, two cards to a column
          "place": root.at(8 + Math.floor(n / 8) * 4 + n % 2 * 2, Math.floor(n % 8 / 2) * 2, 2, 2)
        }));
  }

  modules: [
    {
      "type": "WallpaperPicker",
      "place": root.at(0, 0, 4, 8)
    },
    {
      "type": "ThemeEditor",
      "place": root.at(4, 0, 4, 8)
    }
  ].concat(root.swatches())
}
