import QtQuick
import QtTest
import qs.components.methods

TestCase {
  name: "SurfaceOutline"

  // Radius 28, stroke 2, connector gap 56: a fillet takes 27 along the
  // edge, its arc's run
  function spec(extra) {
    return Object.assign({
      "edge": SurfaceOutline.top,
      "boxAlong": 200,
      "boxDepth": 100,
      "strokeWidth": 2,
      "filletRadius": 28,
      "cornerRadius": 27,
      "connectorGap": 56,
      "joinStart": false,
      "joinEnd": false,
      "flushStart": false,
      "flushEnd": false,
      "detached": false,
      "detachedOffset": 0,
      "backfill": 0,
      "straight": false,
      "straightJoins": false
    }, extra);
  }

  function test_metrics_attached() {
    const m = SurfaceOutline.metrics(spec({}));
    compare(m.startMargin, 27);
    compare(m.endMargin, 27);
    compare(m.alongLength, 254);
    // A deep box starts on the attach edge
    compare(m.boxStart, 0);
    compare(m.depth, 128);
    compare(m.sideU, 28);
    compare(m.farV, 99);
  }

  function test_metrics_shallow_box_pushed_back() {
    // fillet 29 + corner 27 + half 1 - depth 20 = 37, capped at half the gap
    compare(SurfaceOutline.metrics(spec({
      "boxDepth": 20
    })).boxStart, 28);
  }

  function test_metrics_joined_and_sharp() {
    const joined = SurfaceOutline.metrics(spec({
      "joinStart": true
    }));
    compare(joined.startMargin, 0);
    verify(joined.joinFillet);
    compare(joined.depth, 156);
    const sharp = SurfaceOutline.metrics(spec({
      "filletRadius": 0
    }));
    verify(sharp.sharp);
    compare(sharp.startMargin, 0);
    verify(sharp.straightJoins);
  }

  function test_straight_join_per_end() {
    // A pill on a bare edge: straight off the screen edge at its start,
    // a fillet into a solid bar's stroke at its end
    const s = spec({
      "joinStart": true,
      "joinEnd": true,
      "straight": true,
      "straightJoins": true,
      "straightJoinEnd": false
    });
    const m = SurfaceOutline.metrics(s);
    verify(m.straightJoinStart);
    verify(!m.straightJoinEnd);
    verify(!m.straightJoins);
    verify(m.joinFillet, "the end's fillet deepens the surface");
    const fp = SurfaceOutline.footprint(s, m, m.depth, m.alongLength);
    // The box and the end's fillet square only
    compare(fp.length, 2);
    // Both ends straight: no fillet anywhere
    const both = SurfaceOutline.metrics(spec({
      "joinStart": true,
      "joinEnd": true,
      "straightJoins": true
    }));
    verify(!both.joinFillet);
  }

  function test_withBoxStart() {
    const s = spec({});
    const m = SurfaceOutline.withBoxStart(s, SurfaceOutline.metrics(s), 28);
    compare(m.boxStart, 28);
    compare(m.depth, 156);
    compare(m.farV, 127);
    compare(m.naturalBoxStart, 0);
  }

  function test_toItem_edges() {
    // 100 wide, 50 high; u = 10 along, v = 5 away from the edge
    compare(SurfaceOutline.toItem(SurfaceOutline.top, 100, 50, 0, 10, 5), {
      "x": 10,
      "y": 5
    });
    compare(SurfaceOutline.toItem(SurfaceOutline.bottom, 100, 50, 0, 10, 5), {
      "x": 10,
      "y": 45
    });
    compare(SurfaceOutline.toItem(SurfaceOutline.left, 50, 100, 1, 10, 5), {
      "x": 6,
      "y": 10
    });
    compare(SurfaceOutline.toItem(SurfaceOutline.right, 50, 100, 0, 10, 5), {
      "x": 45,
      "y": 10
    });
  }

  function test_footprint_attached_top() {
    const s = spec({});
    const m = SurfaceOutline.metrics(s);
    const sz = SurfaceOutline.size(s, m);
    compare(sz, {
      "width": 254,
      "height": 128
    });
    compare(SurfaceOutline.footprint(s, m, sz.width, sz.height), [
      {
        "x": 27,
        "y": 0,
        "width": 200,
        "height": 100
      },
      {
        "x": 0,
        "y": 0,
        "width": 27,
        "height": 29
      },
      {
        "x": 227,
        "y": 0,
        "width": 27,
        "height": 29
      }
    ]);
  }

  function test_footprint_bottom_is_mirrored() {
    const s = spec({
      "edge": SurfaceOutline.bottom
    });
    const m = SurfaceOutline.metrics(s);
    const fp = SurfaceOutline.footprint(s, m, 254, 128);
    // The box reaches down to the attach edge at the bottom
    compare(fp[0], {
      "x": 27,
      "y": 28,
      "width": 200,
      "height": 100
    });
    compare(fp[1].y, 99);
  }

  function test_footprint_detached_is_the_box() {
    const s = spec({
      "detached": true,
      "detachedOffset": 10
    });
    const m = SurfaceOutline.metrics(s);
    compare(SurfaceOutline.footprint(s, m, 254, 166), [
      {
        "x": 27,
        "y": 38,
        "width": 200,
        "height": 100
      }
    ]);
  }

  function test_footprint_join_and_backfill() {
    const s = spec({
      "joinEnd": true,
      "backfill": 1
    });
    const m = SurfaceOutline.metrics(s);
    const fp = SurfaceOutline.footprint(s, m, m.alongLength, m.depth);
    // The box, the start fillet, the joined end's fillet, the backfill row
    compare(fp.length, 4);
    compare(fp[2], {
      "x": 198,
      "y": 100,
      "width": 29,
      "height": 29
    });
    compare(fp[3], {
      "x": 0,
      "y": 0,
      "width": 227,
      "height": 1
    });
  }

  function test_paths() {
    const s = spec({});
    const m = SurfaceOutline.metrics(s);
    compare(SurfaceOutline.fillPath(s, m, 0, 0), "");
    const fill = SurfaceOutline.fillPath(s, m, 254, 128);
    verify(fill.startsWith("M 0 0 L 0 1 "));
    verify(fill.endsWith("Z"));
    // Top edge: the fillet sweeps clockwise; on the bottom edge it flips
    verify(SurfaceOutline.strokePath(s, m, 254, 128).indexOf("A 28 28 0 0 1 28 29") >= 0);
    const b = spec({
      "edge": SurfaceOutline.bottom
    });
    verify(SurfaceOutline.strokePath(b, SurfaceOutline.metrics(b), 254, 128).indexOf("A 28 28 0 0 0 28 99") >= 0);
  }

  function test_join_fill_stops_short_of_stroke_end() {
    // A joined end's fill covers the stroke it meets a pixel short of the
    // fillet's flat cap, so it can't show through the cap's soft edge
    const s = spec({
      "joinStart": true,
      "joinEnd": true
    });
    const m = SurfaceOutline.metrics(s);
    const w = m.alongLength, h = m.depth, v = m.farV + 28;
    const fill = SurfaceOutline.fillPath(s, m, w, h);
    verify(fill.startsWith("M 0 0 L 0 " + (v - 1) + " L 1 " + (v - 1) + " L 1 " + v + " "), fill);
    verify(fill.indexOf((w - 1) + " " + v + " L " + (w - 1) + " " + (v - 1) + " L " + w + " " + (v - 1) + " ") >= 0, fill);
    // The stroke still runs to the stroke it meets
    verify(SurfaceOutline.strokePath(s, m, w, h).trim().endsWith((w - 1) + " " + v));
  }
}
