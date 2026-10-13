import QtQuick
import QtTest
import qs.components.methods

TestCase {
  name: "EdgeAttach"

  // Radius 28, stroke 2, connector gap 56: a fillet takes 27 along the
  // edge (its arc's run), and on an island 55 (the island's corner too)
  function spec(extra) {
    return Object.assign({
      "pills": [],
      "island": false,
      "merge": 0,
      "centre": 0,
      "aligned": 0,
      "length": 100,
      "joinStart": false,
      "joinEnd": false,
      "joinFrom": -2,
      "joinTo": 1002,
      "lo": 54,
      "hi": 946,
      "islandFrom": 0,
      "islandTo": 1000,
      "straight": false,
      "straightMerged": false,
      "gap": 56,
      "stroke": 2,
      "radius": 28
    }, extra);
  }

  function pill(start, length, joinStart, joinEnd) {
    return {
      "start": start,
      "length": length,
      "joinStart": joinStart ?? false,
      "joinEnd": joinEnd ?? false
    };
  }

  function test_filletMargin() {
    compare(EdgeAttach.filletMargin(56, 2, 28), 27);
    // Too tight a radius for a fillet
    compare(EdgeAttach.filletMargin(0, 2, 0), 0);
  }

  function test_joins() {
    // Pushed back from the start, or within a connector gap of it
    compare(EdgeAttach.joins(60, 100, 54, 946, 56, true, true), {
      "joinStart": true,
      "joinEnd": false
    });
    compare(EdgeAttach.joins(200, 100, 54, 946, 56, true, true), {
      "joinStart": false,
      "joinEnd": false
    });
    compare(EdgeAttach.joins(850, 100, 54, 946, 56, true, true), {
      "joinStart": false,
      "joinEnd": true
    });
    // Nothing to join there
    compare(EdgeAttach.joins(60, 100, 54, 946, 56, false, true).joinStart, false);
    // Content that fills any room joins both
    compare(EdgeAttach.joins(0, Infinity, 54, 946, 56, true, true), {
      "joinStart": true,
      "joinEnd": true
    });
  }

  function test_pillAt() {
    const pills = [pill(100, 100), pill(400, 100)];
    compare(EdgeAttach.pillAt(pills, 150, false).index, 0);
    // Between pills: none, but an island takes the nearest
    compare(EdgeAttach.pillAt(pills, 320, false), null);
    compare(EdgeAttach.pillAt(pills, 320, true).index, 1);
    compare(EdgeAttach.pillAt([], 320, true), null);
  }

  function test_plain_keeps_content_in_place() {
    const p = EdgeAttach.place(spec({
      "aligned": 300.4
    }));
    compare(p.mode, "plain");
    compare([p.start, p.end, p.grow, p.contentOffset], [300, 400, 0, 0]);
    compare([p.startMargin, p.endMargin, p.surfaceStart, p.surfaceLength], [27, 27, 273, 154]);
    compare(p.stretch, null);
    // Past its range it's pulled back in
    compare(EdgeAttach.place(spec({
      "aligned": 900
    })).start, 846);
    // A bare screen edge has no fillets
    const bare = EdgeAttach.place(spec({
      "aligned": 300,
      "straight": true
    }));
    compare([bare.startMargin, bare.endMargin], [0, 0]);
  }

  function test_plain_stops_at_a_wall() {
    // Nothing to join at the end: the surface, its fillet included, goes
    // up to where windows start, keeping their gap from what's past it
    const p = EdgeAttach.place(spec({
      "aligned": 900,
      "wallTo": 800
    }));
    compare([p.start, p.end, p.endMargin, p.joinEnd], [673, 773, 27, false]);
    compare(p.surfaceStart + p.surfaceLength, 800);
    const q = EdgeAttach.place(spec({
      "aligned": 0,
      "wallFrom": 200
    }));
    compare([q.start, q.startMargin, q.joinStart, q.surfaceStart], [227, 27, false, 200]);
  }

  function test_pill_stops_at_a_wall() {
    // The end pill joins the edge past the wall: the box doesn't follow it
    const pills = [pill(300, 702, false, true)];
    const p = EdgeAttach.place(spec({
      "pills": pills,
      "pillBar": true,
      "centre": 900,
      "aligned": 900,
      "pillGrows": true,
      "wallTo": 800
    }));
    compare([p.start, p.end, p.joinEnd, p.flushEnd, p.endMargin], [673, 773, false, false, 27]);
    compare(p.stretch, null);
    // Without one it joins the edge
    compare(EdgeAttach.place(spec({
      "pills": pills,
      "pillBar": true,
      "centre": 900,
      "aligned": 900,
      "pillGrows": true
    })).joinEnd, true);
    // A wall near what pills reach: the full fillet and the pill's full
    // corner still fit inside both, the content moving in for them
    for (const wall of [950, 990]) {
      const q = EdgeAttach.place(spec({
        "pills": pills,
        "pillBar": true,
        "centre": 900,
        "aligned": 900,
        "pillGrows": true,
        "wallTo": wall
      }));
      compare(q.endMargin, 27, `wall ${wall}`);
      verify(q.surfaceStart + q.surfaceLength <= wall, `wall ${wall}: surface past it`);
      compare(q.stretch?.cornerEnd, undefined);
    }
  }

  function test_island_wall_pushes_the_box() {
    // A floating bar owning the corner: its island reaches past the wall
    // over the bar it pushes aside. Short of room for a full fillet inside
    // the wall and the island's corner, the box moves in; nothing rounds
    // less
    const at = wall => EdgeAttach.place(spec({
        "island": true,
        "pills": [pill(10, 980)],
        "islandFrom": 10,
        "centre": 50,
        "aligned": 0,
        "wallFrom": wall
      }));
    for (const wall of [30, 50, 70, 100]) {
      const p = at(wall);
      compare(p.startMargin, 27, `wall ${wall}`);
      verify(p.surfaceStart >= wall, `wall ${wall}: fillet past it`);
      verify(p.start - 10 >= 27 + 28, `wall ${wall}: no room for the island's corner`);
      compare(p.stretch?.cornerStart, undefined);
    }
    compare(at(70).start, 97);
    compare(at(30).start, 65);
  }

  function test_pill_grows_past_a_wall_for_the_fillet() {
    const p = EdgeAttach.place(spec({
      "pills": [pill(300, 520)],
      "pillBar": true,
      "centre": 600,
      "aligned": 900,
      "pillGrows": true,
      "wallTo": 800
    }));
    compare([p.end, p.flushEnd, p.endMargin], [773, false, 27]);
    compare([p.stretch.end, p.stretch.squareEnd], [828, false]);
  }

  function test_island_stops_at_a_wall() {
    const p = EdgeAttach.place(spec({
      "island": true,
      "pills": [pill(100, 890)],
      "centre": 900,
      "aligned": 900,
      "wallTo": 800
    }));
    compare([p.mode, p.end, p.flushEnd, p.endMargin], ["island", 773, false, 27]);
  }

  function test_joined_box_reaches_the_stroke() {
    const p = EdgeAttach.place(spec({
      "aligned": 60,
      "joinStart": true
    }));
    compare([p.start, p.end, p.contentStart, p.contentOffset, p.grow], [-2, 160, 60, 62, 62]);
    compare([p.startMargin, p.endMargin], [0, 27]);
    // Both joined: stroke to stroke
    const both = EdgeAttach.place(spec({
      "aligned": 400,
      "joinStart": true,
      "joinEnd": true
    }));
    compare([both.start, both.end, both.contentStart], [-2, 1002, 400]);
  }

  function test_stands_on_its_pill() {
    const p = EdgeAttach.place(spec({
      "pills": [pill(100, 400)],
      "centre": 200,
      "aligned": 150,
      "length": 100
    }));
    compare(p.mode, "pill");
    compare(p.pill.index, 0);
    // Its fillet won't fit before the pill's start: it runs flush into it,
    // the content staying put
    compare([p.start, p.end, p.contentStart, p.flushStart, p.flushEnd], [100, 250, 150, true, false]);
    compare([p.stretch.start, p.stretch.end, p.stretch.squareStart], [100, 500, true]);
    // Well inside, no stretch
    compare(EdgeAttach.place(spec({
      "pills": [pill(0, 1000)],
      "centre": 500,
      "aligned": 450
    })).stretch, null);
  }

  function test_extends_its_pill_like_an_island() {
    const p = EdgeAttach.place(spec({
      "pills": [pill(100, 200), pill(600, 300)],
      "pillBar": true,
      "centre": 250,
      "aligned": 200,
      "length": 200
    }));
    compare(p.mode, "pill");
    compare([p.start, p.end, p.flushStart, p.flushEnd], [200, 400, false, true]);
    // Stretched out to the box's end, squared there
    compare([p.stretch.index, p.stretch.start, p.stretch.end, p.stretch.squareEnd], [0, 100, 400, true]);
    // A pill bar showing none grows from its outer edge
    compare(EdgeAttach.place(spec({
      "pillBar": true,
      "aligned": 300
    })).mode, "merged");
  }

  function test_joins_where_its_pill_joins_the_edge() {
    const p = EdgeAttach.place(spec({
      "pills": [pill(-2, 300, true, false)],
      "pillBar": true,
      "centre": 100,
      "aligned": 50,
      "length": 200
    }));
    compare([p.start, p.joinStart, p.flushStart, p.startMargin, p.contentStart], [-2, true, false, 0, 50]);
    compare([p.end, p.flushEnd], [298, true]);
  }

  function test_pill_joins_the_edge_it_comes_within_a_gap_of() {
    // Its fillet fits before the pill's end, but the box is within a
    // connector gap of the edge (joins): it joins, from its pill
    const p = EdgeAttach.place(spec({
      "pills": [pill(-2, 300, true, false)],
      "pillBar": true,
      "centre": 100,
      "aligned": 80,
      "length": 100,
      "joinStart": true,
      "pillJoins": true,
      "pillFrom": -2,
      "pillTo": 1002,
      "pillGrows": true
    }));
    compare([p.mode, p.start, p.joinStart, p.startMargin, p.contentStart], ["pill", -2, true, 0, 80]);
  }

  function test_pill_joins_the_stroke_it_runs_on_past() {
    // A pill joining the edge runs on past its stroke (under a bar making
    // way for this one at that corner): a side whose fillet would pass the
    // stroke joins it there
    const p = EdgeAttach.place(spec({
      "pills": [pill(700, 360, false, true)],
      "pillBar": true,
      "centre": 850,
      "aligned": 900,
      "length": 100,
      "joinTo": 1002,
      "pillGrows": true
    }));
    compare([p.mode, p.end, p.joinEnd, p.flushEnd, p.endMargin], ["pill", 1002, true, false, 0]);
    compare(p.stretch, null, "the pill already reaches past it");
  }

  function test_pill_joins_the_edges_with_the_box() {
    // A box filling the edge on a pill bar joins both ends from the pill
    // under its centre, which stretches to the bar's ends and joins them
    const p = EdgeAttach.place(spec({
      "pills": [pill(20, 100), pill(450, 100), pill(880, 100)],
      "pillBar": true,
      "centre": 500,
      "aligned": -2,
      "length": 1004,
      "joinStart": true,
      "joinEnd": true,
      "pillJoins": true,
      "pillFrom": -3,
      "pillTo": 1003,
      "pillGrows": true
    }));
    compare([p.mode, p.start, p.end, p.joinStart, p.joinEnd, p.flushStart, p.flushEnd], ["pill", -2, 1002, true, true, false, false]);
    compare([p.stretch.index, p.stretch.start, p.stretch.end, p.stretch.joinStart, p.stretch.joinEnd, p.stretch.squareStart, p.stretch.squareEnd], [1, -3, 1003, true, true, false, false]);
    // Not joining the edges, it runs flush into its pill's stretch
    const q = EdgeAttach.place(spec({
      "pills": [pill(20, 100), pill(450, 100), pill(880, 100)],
      "pillBar": true,
      "centre": 500,
      "aligned": -2,
      "length": 1004,
      "pillJoins": true,
      "pillGrows": true
    }));
    compare([q.joinStart, q.flushStart, q.stretch.joinStart], [false, true, false]);
  }

  function test_island_fits() {
    const p = EdgeAttach.place(spec({
      "island": true,
      "pills": [pill(100, 800)],
      "centre": 400,
      "aligned": 300,
      "length": 200
    }));
    compare(p.mode, "island");
    compare([p.start, p.end, p.flushStart, p.flushEnd, p.contentOffset], [300, 500, false, false, 0]);
    compare(p.stretch, null);
  }

  function test_island_short_side_reaches_its_end() {
    const p = EdgeAttach.place(spec({
      "island": true,
      "pills": [pill(100, 800)],
      "centre": 220,
      "aligned": 120,
      "length": 200
    }));
    // The content stays put; the box reaches back to the island's start
    compare([p.start, p.end, p.contentStart, p.contentOffset], [100, 320, 120, 20]);
    compare([p.flushStart, p.flushEnd, p.startMargin, p.endMargin], [true, false, 0, 27]);
    compare([p.stretch.start, p.stretch.end, p.stretch.squareStart, p.stretch.squareEnd], [100, 900, true, false]);
  }

  function test_island_shorter_than_the_box_stretches() {
    // A centred launcher over a narrower island: neither moves the content
    const p = EdgeAttach.place(spec({
      "island": true,
      "pills": [pill(400, 200)],
      "centre": 500,
      "aligned": 300,
      "length": 400
    }));
    compare([p.start, p.end, p.contentOffset, p.flushStart, p.flushEnd], [300, 700, 0, true, true]);
    compare([p.stretch.start, p.stretch.end, p.stretch.squareStart, p.stretch.squareEnd], [300, 700, true, true]);
  }

  function test_island_reaches_neighbours_within_merge() {
    // The next island is near enough to join, so the end keeps its fillet
    const p = EdgeAttach.place(spec({
      "island": true,
      "merge": 30,
      "pills": [pill(100, 200), pill(320, 180)],
      "centre": 200,
      "aligned": 150,
      "length": 200
    }));
    compare([p.flushStart, p.flushEnd], [true, false]);
    compare([p.stretch.index, p.stretch.start, p.stretch.end], [0, 100, 405]);
  }

  function test_island_nearest_when_centred_between() {
    const p = EdgeAttach.place(spec({
      "island": true,
      "pills": [pill(100, 100), pill(700, 100)],
      "centre": 500,
      "aligned": 400,
      "length": 200
    }));
    compare(p.pill.index, 1);
    // The island stretches back under the box: its start runs flush into
    // the stretched end, its end keeps a fillet on the island
    compare([p.start, p.end, p.contentStart, p.flushStart, p.flushEnd], [400, 600, 400, true, false]);
    compare([p.stretch.start, p.stretch.end], [400, 800]);
  }

  function test_nudge_up_to_the_pill_end() {
    // 20 short of room for its fillet before the pill's start: up to it,
    // flush and no empty box, rather than 62 back
    const p = EdgeAttach.place(spec({
      "pills": [pill(100, 400)],
      "centre": 170,
      "aligned": 120,
      "nudge": true
    }));
    compare([p.start, p.end, p.contentStart, p.grow, p.flushStart, p.flushEnd], [100, 200, 100, 0, true, false]);
    // The same at the end
    const q = EdgeAttach.place(spec({
      "pills": [pill(100, 400)],
      "centre": 430,
      "aligned": 380,
      "nudge": true
    }));
    compare([q.start, q.end, q.contentStart, q.grow, q.flushStart, q.flushEnd], [400, 500, 400, 0, false, true]);
  }

  function test_nudge_back_for_the_fillet() {
    // 50 in from the pill's start: 5 back gives it its fillet instead
    const p = EdgeAttach.place(spec({
      "pills": [pill(100, 400)],
      "centre": 200,
      "aligned": 150,
      "nudge": true
    }));
    compare([p.start, p.end, p.contentStart, p.grow, p.flushStart, p.startMargin], [155, 255, 155, 0, false, 27]);
    compare(p.stretch, null);
  }

  function test_nudge_leaves_both_short_sides() {
    // Too narrow a pill for either fillet: nothing to gain by moving
    const p = EdgeAttach.place(spec({
      "island": true,
      "pills": [pill(400, 200)],
      "centre": 500,
      "aligned": 300,
      "length": 400,
      "nudge": true
    }));
    compare([p.start, p.end, p.contentStart, p.flushStart, p.flushEnd], [300, 700, 300, true, true]);
  }

  function test_pill_grows_for_a_fillet_short_of_its_start() {
    // 50 in from the pill's start, 5 short of a fillet's room: the pill
    // grows back under it, the box keeping to its content
    const p = EdgeAttach.place(spec({
      "pills": [pill(100, 400)],
      "pillBar": true,
      "centre": 200,
      "aligned": 150,
      "pillGrows": true
    }));
    compare([p.start, p.end, p.contentStart, p.grow, p.flushStart, p.startMargin], [150, 250, 150, 0, false, 27]);
    compare([p.stretch.start, p.stretch.end, p.stretch.squareStart], [95, 500, false]);
  }

  function test_pill_grows_for_a_fillet_short_of_its_end() {
    const p = EdgeAttach.place(spec({
      "pills": [pill(100, 400)],
      "pillBar": true,
      "centre": 430,
      "aligned": 380,
      "pillGrows": true
    }));
    compare([p.start, p.end, p.grow, p.flushEnd, p.endMargin], [380, 480, 0, false, 27]);
    compare([p.stretch.start, p.stretch.end, p.stretch.squareEnd], [100, 535, false]);
  }

  function test_island_grows_towards_a_neighbour_within_merge() {
    // Its fillet room reaches within merge of the next island: the two
    // draw as one, and the box keeps to its content at both ends
    const p = EdgeAttach.place(spec({
      "island": true,
      "merge": 30,
      "pills": [pill(100, 200), pill(320, 180)],
      "centre": 200,
      "aligned": 150,
      "length": 200,
      "pillGrows": true
    }));
    compare([p.start, p.end, p.grow, p.flushStart, p.flushEnd], [150, 350, 0, false, false]);
    compare([p.stretch.index, p.stretch.start, p.stretch.end], [0, 95, 405]);
  }

  function test_pill_grows_not_past_where_islands_reach() {
    // No room past the island's start for the fillet: flush, as without
    const p = EdgeAttach.place(spec({
      "island": true,
      "pills": [pill(20, 800)],
      "centre": 100,
      "aligned": 50,
      "pillGrows": true
    }));
    compare([p.start, p.contentStart, p.flushStart, p.startMargin], [20, 50, true, 0]);
  }

  function test_pill_grows_still_joins_the_edge() {
    const p = EdgeAttach.place(spec({
      "pills": [pill(-2, 300, true, false)],
      "pillBar": true,
      "centre": 100,
      "aligned": 50,
      "length": 200,
      "pillGrows": true
    }));
    compare([p.start, p.joinStart, p.flushStart, p.contentStart], [-2, true, false, 50]);
  }

  function test_reachStretch() {
    const p = Object.assign(pill(400, 200), {
      "index": 2
    });
    // Nothing to reach: its own stretch as it was
    compare(EdgeAttach.reachStretch(null, p, null), null);
    compare(EdgeAttach.reachStretch(null, null, 100), null);
    // Past the pill's start: stretched there and squared
    compare(EdgeAttach.reachStretch(null, p, 300), {
      "index": 2,
      "start": 300,
      "end": 600,
      "squareStart": true,
      "squareEnd": false,
      "joinStart": false,
      "joinEnd": false
    });
    // Within its own stretch: as it was, an end it squared kept square
    const own = {
      "index": 2,
      "start": 350,
      "end": 650,
      "squareStart": false,
      "squareEnd": true,
      "joinStart": false,
      "joinEnd": false
    };
    compare(EdgeAttach.reachStretch(own, p, 500), own);
    compare(EdgeAttach.reachStretch(own, p, 650).squareEnd, true);
    compare(EdgeAttach.reachStretch(own, p, 700), Object.assign({}, own, {
      "end": 700,
      "squareEnd": true
    }));
  }

  function test_joinOpening() {
    // A top bar's surface joined at its start covers the left edge's
    // stroke from the screen's top down to its join
    compare(EdgeAttach.joinOpening("top", true, 10, 100, 60, 1440), {
      "edge": "left",
      "start": 0,
      "end": 70
    });
    // A left edge's joined at its end: the bottom edge's, from the left
    compare(EdgeAttach.joinOpening("left", false, 12, 500, 40, 3440), {
      "edge": "bottom",
      "start": 0,
      "end": 52
    });
    // From the far side: a right edge's, up to the screen's width
    compare(EdgeAttach.joinOpening("right", true, 3000, 400, 50, 3440), {
      "edge": "top",
      "start": 3350,
      "end": 3440
    });
    // With its fillet: at the far end of its cover, which is the
    // stretch's end from the near side and its start from the far one
    compare(EdgeAttach.joinOpening("top", true, 10, 100, 60, 1440, 24), {
      "edge": "left",
      "start": 0,
      "end": 70,
      "fillet": 24,
      "filletAtEnd": true
    });
    compare(EdgeAttach.joinOpening("right", true, 3000, 400, 50, 3440, 24), {
      "edge": "top",
      "start": 3350,
      "end": 3440,
      "fillet": 24,
      "filletAtEnd": false
    });
    // None, or a straight join's 0, adds nothing
    compare(EdgeAttach.joinOpening("top", true, 10, 100, 60, 1440, 0), {
      "edge": "left",
      "start": 0,
      "end": 70
    });
  }

  function test_pill_grows_runs_flush_past_its_end() {
    // Content past the island's ends: flush, the island stretched to it
    const p = EdgeAttach.place(spec({
      "island": true,
      "pills": [pill(400, 200)],
      "centre": 500,
      "aligned": 300,
      "length": 400,
      "pillGrows": true
    }));
    compare([p.start, p.end, p.grow, p.flushStart, p.flushEnd], [300, 700, 0, true, true]);
  }
}
