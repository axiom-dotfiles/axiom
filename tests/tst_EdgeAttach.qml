import QtQuick
import QtTest
import qs.components.methods

TestCase {
  name: "EdgeAttach"

  // Radius 28, stroke 2, connector gap 56: a fillet takes 54 along the
  // edge, and on an island 82 (the island's corner too)
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
    compare(EdgeAttach.filletMargin(56, 2, 28), 54);
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
    compare([p.startMargin, p.endMargin, p.surfaceStart, p.surfaceLength], [54, 54, 246, 208]);
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

  function test_joined_box_reaches_the_stroke() {
    const p = EdgeAttach.place(spec({
      "aligned": 60,
      "joinStart": true
    }));
    compare([p.start, p.end, p.contentStart, p.contentOffset, p.grow], [-2, 160, 60, 62, 62]);
    compare([p.startMargin, p.endMargin], [0, 54]);
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
    // Its fillet runs past the pill's start: the pill stretches to carry it
    compare([p.stretch.index, p.stretch.start, p.stretch.end], [0, 68, 500]);
    // Well inside, no stretch
    compare(EdgeAttach.place(spec({
      "pills": [pill(0, 1000)],
      "centre": 500,
      "aligned": 450
    })).stretch, null);
  }

  function test_merges_around_pills() {
    const pills = [pill(100, 200), pill(600, 300)];
    const p = EdgeAttach.place(spec({
      "pills": pills,
      "pillBar": true,
      "centre": 250,
      "aligned": 200,
      "length": 200
    }));
    compare(p.mode, "merged");
    compare(p.stretch, null);
    // The first pill carries on past its start: that wall stands on it
    compare([p.footStart, p.footEnd], [true, false]);
    compare(p.mergedPills.length, 1);
    // A pill bar showing none still merges
    compare(EdgeAttach.place(spec({
      "pillBar": true,
      "aligned": 300
    })).mode, "merged");
  }

  function test_snap_reaches_onto_a_pill_without_moving_the_content() {
    // Its end falls 20 short of the second pill's stroke
    const p = EdgeAttach.place(spec({
      "pills": [pill(100, 200), pill(522, 300)],
      "pillBar": true,
      "centre": 250,
      "aligned": 200,
      "length": 304
    }));
    compare([p.start, p.end, p.contentStart, p.contentOffset], [200, 524, 200, 0]);
    compare(p.footEnd, true);
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
    compare([p.flushStart, p.flushEnd, p.startMargin, p.endMargin], [true, false, 0, 54]);
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
    compare([p.stretch.index, p.stretch.start, p.stretch.end], [0, 100, 432]);
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

  function test_notches() {
    const n = EdgeAttach.notches([pill(100, 200), pill(0, 50, true, false)], 80, 300, 3);
    compare(n[0], {
      "start": 23,
      "length": 194,
      "roundStart": true,
      "roundEnd": true
    });
    compare([n[1].start, n[1].roundStart, n[1].roundEnd], [-80, false, true]);
  }
}
