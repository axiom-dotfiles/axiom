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
        "count": 2,
        "members": [0, 1]
      },
      {
        "start": 3,
        "count": 1,
        "members": [3]
      }
    ]);
  }

  // A widget showing nothing (null) leaves a run whole; one shown without
  // a background (false) still ends it
  function test_runs_pass_over_widgets_showing_nothing() {
    compare(BarLayout.runs([null, true, null, true, false, true, null]), [
      {
        "start": 1,
        "count": 2,
        "members": [1, 3]
      },
      {
        "start": 5,
        "count": 1,
        "members": [5]
      }
    ]);
    compare(BarLayout.runs([null, null]), []);
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

  function test_runPlaces_skip_widgets_showing_nothing() {
    const places = BarLayout.runPlaces([true, null, true]);
    compare(places[1], null);
    compare(places[2], {
      "run": 0,
      "index": 1,
      "count": 2
    });
  }

  function test_islandRects_whole_bar() {
    compare(BarLayout.islandRects([], 6, 12, 10, 990, true), [
      {
        "start": 10,
        "length": 980,
        "joinStart": false,
        "joinEnd": false
      }
    ]);
  }

  function test_islandRects_grow_clamp_and_merge() {
    // Grown by 6 each side; kept inside 10..990; 100..110 and 115..160
    // become islands 16 apart, within merge 20, so one
    const rects = BarLayout.islandRects([
      {
        "start": 115,
        "end": 160
      },
      {
        "start": 8,
        "end": 50
      },
      {
        "start": 900,
        "end": 988
      },
      {
        "start": 60,
        "end": 75
      }
    ], 6, 20, 10, 990, false);
    compare(rects.map(r => [r.start, r.start + r.length]), [[10, 81], [109, 166], [894, 990]]);
    // 81 to 109 is 28 apart: past merge, so they stay apart
    verify(rects.every(r => !r.joinStart && !r.joinEnd));
  }

  function test_stretchIslands_grows_squares_and_merges() {
    const rects = BarLayout.islandRects([
      {
        "start": 100,
        "end": 200
      },
      {
        "start": 300,
        "end": 400
      }
    ], 0, 10, 0, 1000, false);
    compare(BarLayout.stretchIslands(rects, null, 10).map(r => [r.start, r.length]), [[100, 100], [300, 100]]);
    // Stretched to 80..250: still 50 short of the next
    const apart = BarLayout.stretchIslands(rects, {
      "index": 0,
      "start": 80,
      "end": 250,
      "squareStart": true
    }, 10);
    compare(apart.map(r => [r.start, r.length, r.squareStart, r.squareEnd]), [[80, 170, true, false], [300, 100, false, false]]);
    // Stretched to 295: within 10 of the next, so they draw as one
    const joined = BarLayout.stretchIslands(rects, {
      "index": 0,
      "start": 100,
      "end": 295,
      "squareEnd": true
    }, 10);
    compare(joined.map(r => [r.start, r.length, r.squareStart, r.squareEnd]), [[100, 300, false, false]]);
  }
}
