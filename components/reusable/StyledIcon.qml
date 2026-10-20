pragma ComponentBehavior: Bound
import QtQuick
import qs.config

// A Material Symbols icon: `text` is its name ("wifi"), or several names
// separated by spaces or newlines. Anything else (a glyph or text a user
// typed into an icon field) is drawn in the text font instead.
StyledText {
  id: root

  // -- Public API --
  readonly property bool isSymbol: /^\s*[a-z][a-z0-9_]*(\s+[a-z][a-z0-9_]*)*\s*$/.test(text)
  // Material Symbols' variable axes
  property real fill: 0
  property int weight: 400

  // -- Implementation --
  textFamily: isSymbol ? Appearance.iconFamily : Appearance.fontFamily
  // Filled symbols are built from overlapping contours, which the default
  // distance-field renderer draws as blotches, and curve rendering leaves seams
  // and uneven thin strokes. Native rendering gets both right, but a scaled
  // native glyph is resampled and blurs: grow an icon by size, not `scale`.
  // On a page drawn scaled (an ancestor's `contentZoom`: the overlay's
  // pages), an unfilled one is drawn by the distance-field renderer, which
  // scales cleanly
  renderType: isSymbol && !(root._zoomed && root.fill === 0) ? Text.NativeRendering : Text.QtRendering
  // The ancestor whose `contentZoom` it's drawn at, found once it's placed
  // (var: qmllint knows only Item's members)
  property var _zoomHost: null
  readonly property bool _zoomed: root._zoomHost !== null && Math.abs(root._zoomHost.contentZoom - 1) > 0.01
  Component.onCompleted: {
    for (let item = root.parent; item; item = item.parent) {
      if ("contentZoom" in item) {
        root._zoomHost = item;
        return;
      }
    }
  }
  font.variableAxes: isSymbol ? {
    "FILL": root.fill,
    "wght": root.weight
  } : ({})
}
