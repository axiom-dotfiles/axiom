import QtQuick
import QtTest
import qs.components.methods

TestCase {
  name: "SurfaceOutline"

  // Radius 28, stroke 2, connector gap 56: a fillet takes 54 along the edge
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
    compare(m.startMargin, 54);
    compare(m.endMargin, 54);
    compare(m.alongLength, 308);
    // A deep box starts on the attach edge
    compare(m.boxStart, 0);
    compare(m.depth, 128);
    compare(m.sideU, 55);
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
      "width": 308,
      "height": 128
    });
    compare(SurfaceOutline.footprint(s, m, sz.width, sz.height), [
      {
        "x": 54,
        "y": 0,
        "width": 200,
        "height": 100
      },
      {
        "x": 0,
        "y": 0,
        "width": 54,
        "height": 29
      },
      {
        "x": 254,
        "y": 0,
        "width": 54,
        "height": 29
      }
    ]);
  }

  function test_footprint_bottom_is_mirrored() {
    const s = spec({
      "edge": SurfaceOutline.bottom
    });
    const m = SurfaceOutline.metrics(s);
    const fp = SurfaceOutline.footprint(s, m, 308, 128);
    // The box reaches down to the attach edge at the bottom
    compare(fp[0], {
      "x": 54,
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
    compare(SurfaceOutline.footprint(s, m, 308, 166), [
      {
        "x": 54,
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
    const fp = SurfaceOutline.footprint(s, m, 254, m.depth);
    // The box, the start fillet, the joined end's fillet, the backfill row
    compare(fp.length, 4);
    compare(fp[2], {
      "x": 225,
      "y": 100,
      "width": 29,
      "height": 29
    });
    compare(fp[3], {
      "x": 0,
      "y": 0,
      "width": 254,
      "height": 1
    });
  }

  function test_paths() {
    const s = spec({});
    const m = SurfaceOutline.metrics(s);
    compare(SurfaceOutline.fillPath(s, m, 0, 0), "");
    const fill = SurfaceOutline.fillPath(s, m, 308, 128);
    verify(fill.startsWith("M 0 0 L 0 1 "));
    verify(fill.endsWith("Z"));
    // Top edge: the fillet sweeps clockwise; on the bottom edge it flips
    verify(SurfaceOutline.strokePath(s, m, 308, 128).indexOf("A 28 28 0 0 1 55 29") >= 0);
    const b = spec({
      "edge": SurfaceOutline.bottom
    });
    verify(SurfaceOutline.strokePath(b, SurfaceOutline.metrics(b), 308, 128).indexOf("A 28 28 0 0 0 55 99") >= 0);
  }
}
