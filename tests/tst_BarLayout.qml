import QtQuick
import QtTest
import qs.components.methods

TestCase {
  name: "BarLayout"

  function m(pref, min = pref, priority = 0) {
    return {
      "pref": pref,
      "min": min,
      "priority": priority
    };
  }

  function test_span() {
    compare(BarLayout.span([], 4), 0);
    compare(BarLayout.span([10], 4), 10);
    compare(BarLayout.span([10, 20, 30], 4), 68);
    // Zero sizes take no spacing
    compare(BarLayout.span([10, 0, 30, 0], 4), 44);
  }

  function test_layoutSections_fits() {
    // 1000 long, margin 10, gap 5: ends hug the margins, center centered
    const s = BarLayout.layoutSections([100, 50, 200, 0, 100], [100, 50, 200, 0, 100], 1000, 10, 5, false);
    compare(s[0].offset, 10);
    compare(s[0].extent, 100);
    compare(s[2].offset, 400);
    compare(s[2].extent, 200);
    compare(s[1].offset, 345, "leftCenter sits a gap before the center");
    compare(s[3].extent, 0);
    compare(s[4].offset, 890);
  }

  function test_layoutSections_center_slides() {
    // A long left side pushes the center right (not locked)
    const s = BarLayout.layoutSections([500, 0, 200, 0, 0], [500, 0, 200, 0, 0], 1000, 0, 10, false);
    compare(s[2].offset, 510);
  }

  function test_layoutSections_lockCenter() {
    // Locked, the center stays dead center and the left squeezes instead
    const s = BarLayout.layoutSections([500, 0, 200, 0, 0], [100, 0, 200, 0, 0], 1000, 0, 10, true);
    compare(s[2].offset, 400);
    compare(s[0].extent, 390);
  }

  function test_layoutSections_squeeze_and_scale() {
    // 300 of room: 400 preferred squeezed halfway to the 200 minimum
    const squeezed = BarLayout.layoutSections([200, 0, 0, 0, 200], [100, 0, 0, 0, 100], 300, 0, 0, false);
    compare(squeezed[0].extent, 150);
    compare(squeezed[4].extent, 150);
    // 100 of room: even the minimums don't fit, so they're scaled down
    const scaled = BarLayout.layoutSections([200, 0, 0, 0, 200], [100, 0, 0, 0, 100], 100, 0, 0, false);
    compare(scaled[0].extent, 50);
  }

  function test_overflowHidden_nothing_when_it_fits() {
    const hidden = BarLayout.overflowHidden([[m(100)], [], [m(100)], [], [m(100)]], 1000, 0, 10, 4, false);
    compare(hidden, [[], [], [], [], []]);
  }

  function test_overflowHidden_drops_lowest_priority() {
    // 250 of room for 300: the priority-0 widget goes, wherever it is
    const hidden = BarLayout.overflowHidden([[m(100, 100, 5)], [], [m(100, 100, 0)], [], [m(100, 100, 5)]], 250, 0, 0, 0, false);
    compare(hidden, [[], [], [0], [], []]);
  }

  function test_overflowHidden_ties_go_outer_and_last_first() {
    // Equal priorities: the right section first, its last widget first
    const hidden = BarLayout.overflowHidden([[m(100)], [], [m(100)], [], [m(50), m(50)]], 250, 0, 0, 0, false);
    compare(hidden, [[], [], [], [], [1]]);
  }

  function test_overflowHidden_restores_what_fits() {
    // Dropping the big priority-1 widget leaves room to bring back the
    // priority-0 one dropped before it
    const hidden = BarLayout.overflowHidden([[m(100, 100, 0), m(300, 300, 1)], [], [], [], [m(100, 100, 2)]], 350, 0, 0, 0, false);
    compare(hidden, [[1], [], [], [], []]);
  }

  function test_overflowHidden_lockCenter_only_the_overflowing_half() {
    // Center 200 in 1000 leaves 400 each side; only the left overflows
    const hidden = BarLayout.overflowHidden([[m(300), m(300)], [], [m(200)], [], [m(300)]], 1000, 0, 0, 0, true);
    compare(hidden, [[1], [], [], [], []]);
  }

  function test_allocate_fits() {
    const a = BarLayout.allocate([m(40), m(60)], [true, true], 200, 4);
    compare(a.sizes, [40, 60]);
    compare(a.offsets, [0, 44]);
    compare(a.visible, [true, true]);
  }

  function test_allocate_squeezes_elastic() {
    // 100 preferred + spacing 0 in 80: the elastic one gives 20 of its 50
    const a = BarLayout.allocate([m(50), m(50, 0)], [true, true], 80, 0);
    compare(a.sizes, [50, 30]);
  }

  function test_allocate_hides_lowest_priority() {
    const a = BarLayout.allocate([m(50, 50, 1), m(50, 50, 0)], [true, true], 60, 0);
    compare(a.visible, [true, false]);
    compare(a.sizes, [50, 0]);
  }

  function test_allocate_respects_shown() {
    const a = BarLayout.allocate([m(40), m(60), m(20)], [true, false, true], 200, 4);
    compare(a.sizes, [40, 0, 20]);
    compare(a.offsets, [0, 44, 44]);
  }

  function test_runs() {
    compare(BarLayout.runs([]), []);
    compare(BarLayout.runs([false, false]), []);
    compare(BarLayout.runs([true, true, false, true]), [
      {
        "start": 0,
        "count": 2
      },
      {
        "start": 3,
        "count": 1
      }
    ]);
  }

  function test_runPlaces() {
    const places = BarLayout.runPlaces([true, false, true, true]);
    compare(places[1], null);
    compare(places[0], {
      "run": 0,
      "index": 0,
      "count": 1
    });
    compare(places[3], {
      "run": 1,
      "index": 1,
      "count": 2
    });
  }
}
