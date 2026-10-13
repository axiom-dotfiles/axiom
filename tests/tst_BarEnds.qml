import QtQuick
import QtTest
import qs.components.methods

TestCase {
  name: "BarEnds"

  readonly property var withBorder: ({
      "border": true,
      "borderWidth": 2,
      "gapsOut": {
        "top": 10,
        "bottom": 10,
        "left": 10,
        "right": 10
      }
    })
  readonly property var borderless: Object.assign({}, withBorder, {
    "border": false
  })

  // An enriched bar, as far as BarEnds reads it
  function bar(location, background, extra) {
    const vertical = location === "left" || location === "right";
    const solid = background === "solid";
    return Object.assign({
      "enabled": true,
      "monitor": "DP-1",
      "reserveSpace": true,
      "background": background,
      "solid": solid,
      "island": background === "floating" || background === "floatingPills",
      "insideBorder": !solid,
      "floatGap": 0,
      "floatGapAuto": true,
      "trim": background === "transparent" ? 10 : 0,
      "vertical": vertical,
      "top": location === "top",
      "bottom": location === "bottom",
      "left": location === "left",
      "right": location === "right"
    }, extra ?? {});
  }

  function ends(bars, opts) {
    return BarEnds.withEnds(bars, opts).map(b => b.ends);
  }

  function test_alone_meets_the_frame() {
    const [e] = ends([bar("right", "pills")], withBorder);
    compare(e.start.kind, "border");
    compare(e.end.kind, "border");
    verify(e.end.joinable && !e.end.straight && !e.end.held);
    compare(e.end.reach, 2);
    const [bare] = ends([bar("right", "pills", {
        "insideBorder": false
      })], borderless);
    compare(bare.end.kind, "bare");
    verify(bare.end.straight);
    compare(bare.end.reach, 0);
  }

  function test_same_kind_horizontal_wins() {
    const [side, bottom] = ends([bar("right", "floatingPills"), bar("bottom", "floatingPills")], withBorder);
    compare(side.end.kind, "bar", "the side bar yields at its end");
    verify(side.end.held && !side.end.joinable);
    compare(side.end.reach, 0);
    compare(side.start.kind, "border", "its other end is untouched");
    compare(bottom.end.kind, "border", "the bottom bar keeps the corner");
  }

  function test_pill_bars_merge_at_their_corner() {
    for (const opts of [withBorder, borderless]) {
      const [side, bottom] = ends([bar("right", "pills"), bar("bottom", "pills")], opts);
      compare(side.end.kind, "pillBar", "the side bar joins the bottom bar's pills");
      verify(side.end.joinable && !side.end.held && !side.end.straight);
      compare(side.end.reach, 2, "onto their far stroke");
      compare(bottom.end.kind, opts.border ? "border" : "bare", "the bottom bar keeps the corner");
    }
    const [held] = ends([bar("right", "floatingPills"), bar("bottom", "pills")], withBorder);
    compare(held.end.kind, "bar", "a floating side bar stays held");
  }

  function test_transparent_always_yields() {
    // Screenshot: pills on the right, transparent along the bottom
    const [side, bottom] = ends([bar("right", "pills"), bar("bottom", "transparent")], withBorder);
    compare(side.end.kind, "border");
    compare(bottom.end.kind, "bar");
    verify(bottom.end.held);
    // Its window ends at the pill bar's reserved line, which is its edge
    compare(bottom.end.over, 0);
    compare(bottom.end.gap, 10);
    // Borderless: pills on the left, transparent along the top
    const [left, top] = ends([bar("left", "pills", {
        "insideBorder": false
      }), bar("top", "transparent", {
        "insideBorder": false
      })], borderless);
    compare(left.start.kind, "bare");
    compare(top.start.kind, "bar");
  }

  function test_held_gap_past_a_transparent_bar() {
    // A transparent bar reserves gaps_out short of its edge: the window
    // runs on that far into it, and windows start right at its edge
    const [side] = ends([bar("left", "transparent"), bar("bottom", "transparent")], withBorder);
    compare(side.end.over, 10);
    compare(side.end.gap, 0);
    // A floating bar's own float gap past a bar it yields to
    const [island] = ends([bar("left", "floating", {
        "floatGap": 6,
        "floatGapAuto": false
      }), bar("bottom", "pills")], withBorder);
    compare(island.end.kind, "bar");
    compare(island.end.over, 0);
    compare(island.end.gap, 6);
    // ...which keeps a transparent bar's corner
    const [owner, under] = ends([bar("left", "floating"), bar("bottom", "transparent")], withBorder);
    compare(owner.end.kind, "border");
    compare(under.start.kind, "bar");
  }

  function test_solid_owns_its_corners() {
    const [side, bottom] = ends([bar("right", "solid", {
        "insideBorder": false
      }), bar("bottom", "pills")], withBorder);
    compare(side.end.kind, "border");
    // Inside the border, the bottom bar meets the border's stroke, which
    // lies on the solid bar
    compare(bottom.end.kind, "border");
    verify(bottom.end.joinable && !bottom.end.held);
    compare(bottom.end.reach, 2);
  }

  function test_borderless_joins_a_solid_bars_stroke() {
    // Pills on the left meeting a solid bottom bar curve into its stroke
    const [side] = ends([bar("left", "pills", {
        "insideBorder": false
      }), bar("bottom", "solid", {
        "insideBorder": false
      })], borderless);
    compare(side.end.kind, "solidBar");
    verify(side.end.joinable && !side.end.straight);
    compare(side.end.reach, 2);
    compare(side.start.kind, "bare");
    verify(side.start.straight);
  }

  function test_nothing_yields_to_a_bar_reserving_nothing() {
    const [side] = ends([bar("right", "transparent"), bar("bottom", "pills", {
        "reserveSpace": false
      })], withBorder);
    compare(side.end.kind, "border");
  }

  function test_other_screens_and_disabled_bars_ignored() {
    const [side] = ends([bar("right", "transparent"), bar("bottom", "pills", {
        "monitor": "HDMI-A-1"
      }), bar("top", "pills", {
        "enabled": false
      })], withBorder);
    compare(side.start.kind, "border");
    compare(side.end.kind, "border");
  }
}
