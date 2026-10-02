import QtQuick
import QtTest
import qs.components.methods

TestCase {
  name: "BarShapes"

  // The path's points as [x, y] pairs (arc radii and flags skipped)
  function points(path) {
    const out = [];
    const tokens = path.trim().split(/\s+/);
    for (let i = 0; i < tokens.length; ) {
      const op = tokens[i];
      if (op === "M" || op === "L") {
        out.push([Number(tokens[i + 1]), Number(tokens[i + 2])]);
        i += 3;
      } else if (op === "A") {
        out.push([Number(tokens[i + 6]), Number(tokens[i + 7])]);
        i += 8;
      } else {
        i += 1;
      }
    }
    return out;
  }

  function bounds(path) {
    const pts = points(path);
    return {
      "minX": Math.min(...pts.map(p => p[0])),
      "maxX": Math.max(...pts.map(p => p[0])),
      "minY": Math.min(...pts.map(p => p[1])),
      "maxY": Math.max(...pts.map(p => p[1]))
    };
  }

  function test_flat_is_a_rectangle() {
    compare(BarShapes.path(100, 30, 6, "flat", "flat", false, 0), "M 0 0 L 100 0 L 100 30 L 0 30 Z");
  }

  function test_zero_radius_round_is_square() {
    compare(BarShapes.path(100, 30, 0, "round", "round", false, 0), "M 0 0 L 100 0 L 100 30 L 0 30 Z");
  }

  function test_every_cap_stays_in_its_box_data() {
    return ["flat", "round", "capsule", "arrowOut", "arrowIn", "slant", "roundOut", "roundIn"].map(cap => ({
          "tag": cap,
          "cap": cap
        }));
  }
  function test_every_cap_stays_in_its_box(data) {
    for (const vertical of [false, true]) {
      const b = bounds(BarShapes.path(120, 30, 6, data.cap, data.cap, vertical, 0));
      const w = vertical ? 30 : 120, h = vertical ? 120 : 30;
      verify(b.minX >= 0 && b.maxX <= w && b.minY >= 0 && b.maxY <= h, JSON.stringify(b));
    }
  }

  function test_vertical_swaps_the_axes_and_flips_arcs() {
    const across = BarShapes.path(100, 30, 6, "round", "round", false, 0);
    const down = BarShapes.path(100, 30, 6, "round", "round", true, 0);
    compare(points(down), points(across).map(p => [p[1], p[0]]));
    verify(across.includes("A 6 6 0 0 1"));
    verify(down.includes("A 6 6 0 0 0") && !down.includes("A 6 6 0 0 1"));
  }

  function test_inset_shrinks_all_round() {
    const b = bounds(BarShapes.path(100, 30, 6, "round", "round", false, 1));
    compare([b.minX, b.maxX, b.minY, b.maxY], [1, 99, 1, 29]);
  }

  function test_arrow_points_at_the_end() {
    const pts = points(BarShapes.path(100, 30, 0, "flat", "arrowOut", false, 0));
    verify(pts.some(p => p[0] === 100 && p[1] === 15), "tip mid-way across");
    verify(pts.some(p => p[0] === 85 && p[1] === 0), "shoulder a depth back");
  }

  function test_slant_is_a_parallelogram() {
    // Both sides lean the same way: top inset at the start, bottom at the end
    const pts = points(BarShapes.path(100, 30, 0, "slant", "slant", false, 0));
    compare(pts.slice(0, 4), [[10, 0], [100, 0], [90, 30], [0, 30]]);
  }

  function test_separate_widgets_have_both_ends() {
    const s = BarShapes.segment("arrow", "separate", true, 1, 3, 30);
    compare([s.startCap, s.endCap, s.back, s.lead, s.trail], ["arrowIn", "arrowOut", 0, 15, 15]);
    const r = BarShapes.segment("rounded", "separate", true, 0, 1, 30);
    compare([r.startCap, r.endCap, r.lead, r.trail], ["round", "round", 0, 0]);
  }

  function test_merged_runs_cap_only_their_ends() {
    const first = BarShapes.segment("slant", "merged", true, 0, 3, 30);
    const middle = BarShapes.segment("slant", "merged", true, 1, 3, 30);
    const last = BarShapes.segment("slant", "merged", true, 2, 3, 30);
    compare([first.startCap, first.lead, first.trail], ["slant", 5, 0]);
    compare([middle.startCap, middle.endCap, middle.lead, middle.trail, middle.back], ["flat", "flat", 0, 0, 0]);
    compare([last.endCap, last.trail], ["slant", 5]);
  }

  function test_powerline_segments_overlap() {
    const first = BarShapes.segment("arrow", "powerline", true, 0, 2, 30);
    const second = BarShapes.segment("arrow", "powerline", true, 1, 2, 30);
    compare([first.startCap, first.endCap, first.back], ["round", "arrowOut", 0]);
    // Opaque: square, beneath the arrow before it
    compare([second.startCap, second.back, second.lead], ["flat", 15, 7.5]);
    compare(second.endCap, "arrowOut");
    // See-through: fitted against it instead
    compare(BarShapes.segment("arrow", "powerline", false, 1, 2, 30).startCap, "arrowIn");
    compare(BarShapes.segment("rounded", "powerline", false, 1, 2, 30).startCap, "roundIn");
    compare(BarShapes.segment("slant", "powerline", false, 1, 2, 30).startCap, "slant");
  }
}
