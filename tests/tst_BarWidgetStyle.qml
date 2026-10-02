import QtQuick
import QtTest
import qs.components.methods

TestCase {
  name: "BarWidgetStyle"

  readonly property color accent: "#ff0000"
  readonly property color own: "#000000"
  readonly property color barText: "#ffffff"
  readonly property color custom: "#00ff00"

  function same(actual, expected, message) {
    verify(Qt.colorEqual(actual, expected), `${message}: ${actual} != ${expected}`);
  }

  function styled(fill, override = null) {
    return BarWidgetStyle.colors(fill, accent, own, barText, override, 0.25);
  }

  function test_filled_keeps_the_widgets_own_colors() {
    const c = styled("filled");
    same(c.fill, accent, "fill");
    same(c.text, own, "text");
    same(c.icon, own, "icon");
    same(c.stroke, "transparent", "stroke");
    same(c.indicator, "transparent", "indicator");
  }

  function test_unknown_fill_is_filled() {
    same(styled("nonsense").fill, accent, "fill");
  }

  function test_tinted_is_the_accent_faded_with_accent_text() {
    const c = styled("tinted");
    same(c.fill, Qt.alpha(accent, 0.25), "fill");
    same(c.text, accent, "text");
    same(c.icon, accent, "icon");
  }

  function test_outline_strokes_in_the_accent() {
    const c = styled("outline");
    same(c.fill, "transparent", "fill");
    same(c.stroke, accent, "stroke");
    same(c.text, accent, "text");
  }

  function test_underline_marks_the_accent_with_bar_text() {
    const c = styled("underline");
    same(c.fill, "transparent", "fill");
    same(c.indicator, accent, "indicator");
    same(c.text, barText, "text");
    same(c.icon, barText, "icon");
  }

  function test_accent_text_colors_only_the_icon() {
    const c = styled("accentText");
    same(c.fill, "transparent", "fill");
    same(c.text, barText, "text");
    same(c.icon, accent, "icon");
  }

  function test_plain_is_bar_text_only() {
    const c = styled("plain");
    same(c.fill, "transparent", "fill");
    same(c.text, barText, "text");
    same(c.icon, barText, "icon");
  }

  function test_override_replaces_the_automatic_text_color() {
    ["filled", "tinted", "outline", "underline", "plain"].forEach(fill => {
      const c = styled(fill, custom);
      same(c.text, custom, fill + " text");
      same(c.icon, custom, fill + " icon");
    });
    // The icon stays the state color: that's the point of the style
    const c = styled("accentText", custom);
    same(c.text, custom, "accentText text");
    same(c.icon, accent, "accentText icon");
  }
}
