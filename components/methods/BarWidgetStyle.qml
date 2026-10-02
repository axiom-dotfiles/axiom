pragma Singleton
import QtQuick

// What a bar widget draws in, by its bar's widget style: { fill, stroke,
// indicator, text, icon }. `accent` is the widget's own color for its state
// (its background while filled), `own` its text color (picked to read on
// that background). `style` is the bar's, colors resolved by the caller:
//   fill      Bars[].widgetFill
//   barText   what reads on the bar itself
//   override  the bar's text color, replacing the automatic one, or null
//   tint      a tinted fill's opacity (0-1)
//   group     the shared background of a merged run the widget sits in,
//             or null; the run's own background is colors(style, group)
QtObject {
  id: root

  function colors(style, accent, own) {
    const none = "transparent";
    const text = c => style.override ?? c;
    if (style.group)
      // The run draws the background: the icon keeps the state, the label
      // reads on the run (or on the bar, through a tint or outline)
      return root._make(none, none, none, text(style.fill === "filled" ? root.readableOn(style.group, style.barText) : style.barText), accent);
    switch (style.fill) {
    case "tinted":
      return root._make(Qt.alpha(accent, style.tint), none, none, text(accent), text(accent));
    case "outline":
      return root._make(none, accent, none, text(accent), text(accent));
    case "underline":
      return root._make(none, none, accent, text(style.barText), text(style.barText));
    case "accentText":
      // The icon carries the state, the label reads as the bar's text
      return root._make(none, none, none, text(style.barText), accent);
    case "plain":
      return root._make(none, none, none, text(style.barText), text(style.barText));
    default:
      return root._make(accent, none, none, text(own), text(own));
    }
  }

  // `preferred` if it contrasts with `background`, else black or white
  function readableOn(background, preferred) {
    return Utils.isColorDark(background) !== Utils.isColorDark(preferred) ? preferred : Utils.getContrastColor(background);
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
