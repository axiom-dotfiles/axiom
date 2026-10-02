pragma Singleton
import QtQuick

// What a bar widget draws in, by its bar's widget fill (Bars[].widgetFill):
// { fill, stroke, indicator, text, icon }. `accent` is the widget's own
// color for its state (its background while filled), `own` its text color
// (picked to read on that background), `barText` what reads on the bar
// itself; `override` (or null) is the bar's text color, replacing the
// automatic one. Colors in, colors out: the caller resolves theme names.
QtObject {
  id: root

  function colors(fill, accent, own, barText, override, tintOpacity) {
    const none = "transparent";
    const text = c => override ?? c;
    switch (fill) {
    case "tinted":
      return root._make(Qt.alpha(accent, tintOpacity), none, none, text(accent), text(accent));
    case "outline":
      return root._make(none, accent, none, text(accent), text(accent));
    case "underline":
      return root._make(none, none, accent, text(barText), text(barText));
    case "accentText":
      // The icon carries the state, the label reads as the bar's text
      return root._make(none, none, none, text(barText), accent);
    case "plain":
      return root._make(none, none, none, text(barText), text(barText));
    default:
      return root._make(accent, none, none, text(own), text(own));
    }
  }

  function _make(fill, stroke, indicator, text, icon) {
    return {
      "fill": fill,
      "stroke": stroke,
      "indicator": indicator,
      "text": text,
      "icon": icon
    };
  }
}
