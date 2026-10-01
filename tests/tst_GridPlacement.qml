import QtQuick
import QtTest
import qs.components.methods

TestCase {
  name: "GridPlacement"

  function at(x, y, w, h) {
    return {
      "type": "Test",
      "place": {
        "x": x,
        "y": y,
        "w": w,
        "h": h
      }
    };
  }

  function test_span() {
    // cardUnit 500, cardSpacing 20: a grid unit is 110
    compare(GridPlacement.unitOf(), 110);
    compare(GridPlacement.span(1), 110);
    compare(GridPlacement.span(2), 240, "two units are half a card");
    compare(GridPlacement.span(4), 500, "four units are one card");
    compare(GridPlacement.span(8), 1020, "two cards and the gap between");
    compare(GridPlacement.span(4, 300), 300, "at another card size");
  }

  function test_shapes() {
    compare(GridPlacement.slotShape([0, 0, 2, 2]), "square");
    compare(GridPlacement.slotShape([0, 0, 2, 1]), "horizontal");
    compare(GridPlacement.slotShape([0, 0, 1, 2]), "vertical");
    compare(GridPlacement.slotShape([0, 0, 5, 4]), "square", "near square counts as square");
    compare(GridPlacement.slotShape([0, 0, 4, 3]), "square");
    compare(GridPlacement.slotShape([0, 0, 3, 2]), "horizontal", "from 1.5 times as wide");
    compare(GridPlacement.slotShape([0, 0, 4, 6]), "vertical");
    compare(GridPlacement.slotShape([0, 0, 8, 1]), "horizontal");
    compare(GridPlacement.rectOf({
      "x": 3,
      "y": 1,
      "w": 2,
      "h": 4
    }), [3, 1, 2, 4]);
  }

  function test_bounds() {
    compare(GridPlacement.bounds([]), {
      "cols": 0,
      "rows": 0
    });
    compare(GridPlacement.bounds([at(0, 0, 2, 4), at(2, 1, 4, 2)]), {
      "cols": 6,
      "rows": 4
    });
  }

  function test_canPlace() {
    const modules = [at(0, 0, 2, 2), at(2, 0, 2, 1)];
    verify(GridPlacement.canPlace(modules, {
      "x": 2,
      "y": 1,
      "w": 2,
      "h": 1
    }, -1), "the hole beside");
    verify(!GridPlacement.canPlace(modules, {
      "x": 1,
      "y": 1,
      "w": 2,
      "h": 1
    }, -1), "overlaps the first");
    verify(GridPlacement.canPlace(modules, {
      "x": 1,
      "y": 0,
      "w": 2,
      "h": 2
    }, 0) === false, "still overlaps the second");
    verify(GridPlacement.canPlace(modules, {
      "x": 0,
      "y": 1,
      "w": 2,
      "h": 2
    }, 0), "a module may overlap where it was");
    verify(!GridPlacement.canPlace(modules, {
      "x": -1,
      "y": 0,
      "w": 1,
      "h": 1
    }, -1), "off the grid");
    verify(!GridPlacement.canPlace(modules, {
      "x": 5,
      "y": 0,
      "w": 0,
      "h": 1
    }, -1), "no size");
  }

  function test_firstFree() {
    compare(GridPlacement.firstFree([], 2, 2), {
      "x": 0,
      "y": 0,
      "w": 2,
      "h": 2
    });
    // A hole at (2, 1) in a 4 × 2 grid
    const modules = [at(0, 0, 2, 2), at(2, 0, 2, 1), at(3, 1, 1, 1)];
    compare(GridPlacement.firstFree(modules, 1, 1), {
      "x": 2,
      "y": 1,
      "w": 1,
      "h": 1
    });
    compare(GridPlacement.firstFree(modules, 2, 2), {
      "x": 4,
      "y": 0,
      "w": 2,
      "h": 2
    }, "no room inside: to the right");
    compare(GridPlacement.firstFree([at(0, 0, 8, 2)], 2, 2), {
      "x": 0,
      "y": 2,
      "w": 2,
      "h": 2
    }, "a wide grid grows down");
  }

  function test_normalize() {
    const modules = [at(2, 1, 2, 2), at(4, 3, 1, 1)];
    compare(GridPlacement.normalize(modules), {
      "x": 2,
      "y": 1
    });
    compare(modules[0].place.x, 0);
    compare(modules[0].place.y, 0);
    compare(modules[1].place.x, 2);
    compare(modules[1].place.y, 2);
    compare(GridPlacement.normalize(modules), {
      "x": 0,
      "y": 0
    }, "already at 0");
    compare(GridPlacement.normalize([]), {
      "x": 0,
      "y": 0
    });
  }

  // A 500 px card's unit is 110 px, a step (unit + gap) 130 px
  function test_alongStart() {
    compare(GridPlacement.stepOf(500), 130);
    function start(align, offset, length) {
      return GridPlacement.alongStart(align, offset, length ?? 240, 1000, 500, 10, 10);
    }
    compare(start("start", 0), 10);
    compare(start("start", 2), 270);
    compare(start("end", 0), 750);
    compare(start("end", 1), 620);
    compare(start("center", 0), 380);
    compare(start("center", -1), 250);
    compare(start("start", 10), 750, "kept on the edge");
    compare(start("center", -10), 10);
    compare(start("end", 0, 1200), 10, "longer than the edge: from its start");
  }

  function test_anchorFor() {
    function anchor(start, current) {
      const a = GridPlacement.anchorFor(start, 240, 1000, 500, 10, 10, current);
      return [a.align, a.offset];
    }
    compare(anchor(10), ["start", 0]);
    compare(anchor(750), ["end", 0]);
    compare(anchor(380), ["center", 0]);
    compare(anchor(390, "start"), ["center", 0], "near the middle snaps to it");
    compare(anchor(740, "start"), ["end", 0], "near the end snaps flush");
    compare(anchor(-50, "center"), ["start", 0], "past the start");
    compare(anchor(270, "start"), ["start", 2], "otherwise it keeps its anchor");
    compare(anchor(250, "center"), ["center", -1]);
    compare(anchor(620, "end"), ["end", 1]);
    compare(anchor(620), ["end", 1], "with none, the nearest");
    // Halfway between units, towards the current offset: a centred run
    // grown by one unit and shrunk back doesn't drift
    compare(GridPlacement.anchorFor(380, 370, 1000, 500, 10, 10, "center", 0).offset, 0, "grown: keeps its offset");
    compare(GridPlacement.anchorFor(380 - 65, 240, 1000, 500, 10, 10, "center", 0).offset, 0, "shrunk back: still centred");
    compare(GridPlacement.anchorFor(380 + 65, 240, 1000, 500, 10, 10, "center", 1).offset, 1, "towards a positive offset");
    // Round trips: moved by whole steps from an anchor, it stays put
    ["start", "end", "center"].forEach(align => {
      for (let units = -3; units <= 3; units++) {
        const at = GridPlacement.alongStart(align, 0, 240, 1000, 500, 10, 10) + units * 130;
        // Off the edge, or within half a step of another anchor (it snaps)
        if (at < 10 || at > 750 || [10, 380, 750].some(anchorAt => anchorAt !== at - units * 130 && Math.abs(at - anchorAt) < 65))
          continue;
        const a = GridPlacement.anchorFor(at, 240, 1000, 500, 10, 10, align);
        compare(GridPlacement.alongStart(a.align, a.offset, 240, 1000, 500, 10, 10), at, `${units} from ${align}`);
      }
    });
  }

  function test_screenBox() {
    // As [x, y, w, h] in px (a step is 130 px), as compare() doesn't
    // compare objects by value
    function box(edge, along, across) {
      const b = GridPlacement.screenBox(1020, 500, 500, {
        "cols": 2,
        "rows": 2
      }, edge, along, across);
      return [b.x, b.y, b.w, b.h].map(v => Math.round(v * 130));
    }
    // Its sides lie midway in the gaps: half a gap (10 px) on
    compare(box("Left", 0, 0), [10, 10, 1020, 500], "at the start, against the edge");
    compare(box("Left", 130, 20), [-10, -120, 1020, 500], "a step along, 20 px in");
    // The grid is 240 px across: the screen's right side is 20 px past it
    compare(box("Right", 0, 20), [-750, 10, 1020, 500], "against a right edge");
    compare(box("Top", 260, 0), [-250, 10, 1020, 500], "along a top edge");
    compare(box("Bottom", 0, 0).slice(1, 2), [-250], "against a bottom edge");
  }

  // A rect as [x, y, width, height], as compare() doesn't compare objects
  // by value
  function r4(r) {
    return [r.x, r.y, r.width, r.height].map(v => Math.round(v * 100) / 100);
  }

  function test_fitScale() {
    const bounds = {
      "cols": 8,
      "rows": 4
    };
    compare(GridPlacement.fitScale(bounds, 1200, 600, 500), 1, "fits");
    compare(GridPlacement.fitScale(bounds, 510, 600, 500), 0.5, "half as wide as two cards");
    compare(GridPlacement.fitScale({
      "cols": 0,
      "rows": 0
    }, 10, 10, 500), 1, "nothing to fit");
  }

  function test_menuPlacement_and_onScreen() {
    const frame = {
      "startPad": 10,
      "endPad": 10,
      "across": 20,
      "before": 5,
      "after": 8,
      "reserves": true
    };
    const menu = {
      "edge": "Right",
      "length": "fit",
      "align": "start",
      "offset": 1,
      "modules": [at(0, 0, 2, 4)]
    };
    const place = GridPlacement.menuPlacement(menu, GridPlacement.bounds(menu.modules), 500, frame, 1920, 1080);
    // Two units across (240), four along (500), a step (130) from the start
    compare([place.along, place.across, place.length, place.depth, place.edgeLength], [140, 20, 500, 240, 1080]);
    compare(GridPlacement.menuReservedDepth(place), 268, "across + depth + after");
    frame.reserves = false;
    compare(GridPlacement.menuReservedDepth(place), 5, "a floating menu: what it sits past");
    const onScreen = GridPlacement.menuOnScreen(menu, place, 500);
    // Against the right edge: 1920 - 20 - 240 = 1660
    compare(r4(onScreen.rect), [1652, 132, 256, 516], "the modules plus `after` all round");
    compare(r4(onScreen.modules[0].rect), [1660, 140, 240, 500]);
    menu.length = "edge";
    const whole = GridPlacement.menuOnScreen(menu, GridPlacement.menuPlacement(menu, GridPlacement.bounds(menu.modules), 500, frame, 1920, 1080), 500);
    compare(r4(whole.modules[0].rect), [1660, 10, 240, 1060], "taking the whole edge: stretched along it");
  }

  function test_canvasExtent() {
    const bounds = {
      "cols": 2,
      "rows": 6
    };
    const free = GridPlacement.canvasExtent(bounds, null, 1, 3);
    compare([free.leadCols, free.leadRows, free.cols, free.rows], [1, 1, 12, 10], "at least 8 × 4, plus lead and trail");
    const onScreen = GridPlacement.canvasExtent(bounds, {
      "x": -0.5,
      "y": -2,
      "w": 10,
      "h": 4
    }, 1, 3);
    // One unit past the screen all round; a side exactly on a unit adds none
    compare([onScreen.leadCols, onScreen.leadRows, onScreen.cols, onScreen.rows], [2, 3, 13, 10]);
  }

  function test_canvas_geometry() {
    const extent = {
      "leadCols": 1,
      "leadRows": 1,
      "cols": 10,
      "rows": 6
    };
    // A step is 130 px at the reference size: 1300 × 780 fits at 0.5
    const fit = GridPlacement.canvasFit(extent, 650, 390, 0.6);
    compare([fit.scale, fit.step, fit.gap, fit.unitSize], [0.5, 65, 10, 55]);
    compare([fit.originX, fit.originY], [70, 70], "centred, a lead unit in (plus half a gap)");
    compare(GridPlacement.canvasFit(extent, 6500, 3900, 0.6).scale, 0.6, "at most maxScale");
    compare(r4(GridPlacement.canvasRect(fit, {
      "x": 1,
      "y": 0,
      "w": 2,
      "h": 1
    })), [135, 70, 120, 55]);
    compare(r4(GridPlacement.canvasScreenRect(fit, {
      "x": 0,
      "y": 0,
      "w": 2,
      "h": 1
    })), [65, 65, 130, 65], "its sides midway in the gaps");
    function drop(x, y, w, h, grab) {
      const p = GridPlacement.canvasDropPlace(fit, x, y, w, h, grab);
      return [p.x, p.y, p.w, p.h];
    }
    compare(drop(70, 70, 1, 1, null), [0, 0, 1, 1]);
    compare(drop(200, 140, 3, 3, null), [1, 0, 3, 3], "a new module held by its middle unit");
    compare(drop(200, 140, 3, 3, {
      "x": 0,
      "y": 0
    }), [2, 1, 3, 3], "a moved one by the unit it was grabbed by");
    compare(drop(200, 140, 3, 3, {
      "x": 500,
      "y": 500
    }), [0, -1, 3, 3], "the grab kept inside the module");
  }

  function test_edgeBand_and_edgeBar() {
    const rect = {
      "x": 10,
      "y": 20,
      "width": 100,
      "height": 50
    };
    compare(r4(GridPlacement.edgeBand(rect, "Left", 5)), [10, 20, 5, 50]);
    compare(r4(GridPlacement.edgeBand(rect, "Right", 5)), [105, 20, 5, 50]);
    compare(r4(GridPlacement.edgeBand(rect, "Top", 5)), [10, 20, 100, 5]);
    compare(r4(GridPlacement.edgeBand(rect, "Bottom", 5)), [10, 65, 100, 5]);
    compare(r4(GridPlacement.edgeBand(rect, "", 5)), [0, 0, 0, 0]);
    const span = {
      "x": 30,
      "y": 25,
      "width": 20,
      "height": 10
    };
    compare(r4(GridPlacement.edgeBar(rect, "Left", rect, 4)), [8, 20, 4, 50], "the whole side, centred on it");
    compare(r4(GridPlacement.edgeBar(rect, "Right", span, 4)), [108, 25, 4, 10], "along the span");
    compare(r4(GridPlacement.edgeBar(rect, "Bottom", span, 4)), [30, 68, 20, 4]);
  }

  function test_trackSizes() {
    const natural = GridPlacement.trackSizes({
      "cols": 8,
      "rows": 4
    }, 500);
    compare(natural.unitW, 110);
    compare(natural.unitH, 110);
    compare(natural.width, 1020);
    compare(natural.height, 500);
    const stretched = GridPlacement.trackSizes({
      "cols": 8,
      "rows": 4
    }, 500, {
      "height": 1020
    });
    compare(stretched.unitW, 110, "only the stretched axis grows");
    compare(stretched.unitH, 240);
    compare(stretched.height, 1020);
    const smaller = GridPlacement.trackSizes({
      "cols": 4,
      "rows": 4
    }, 500, {
      "width": 100
    });
    compare(smaller.width, 500, "never below its natural size");
    compare(GridPlacement.trackSizes({
      "cols": 0,
      "rows": 0
    }, 500).width, 0);
  }

  function test_rectPx() {
    const sizes = GridPlacement.trackSizes({
      "cols": 8,
      "rows": 8
    }, 500);
    compare(GridPlacement.rectPx({
      "x": 4,
      "y": 2,
      "w": 4,
      "h": 6
    }, sizes), {
      "x": 520,
      "y": 260,
      "width": 500,
      "height": 760
    });
  }

  function test_moveTo() {
    const arr = ["a", "b", "c"];
    compare(GridPlacement.moveTo(arr, 0, 2), 1);
    compare(arr, ["b", "a", "c"]);
    compare(GridPlacement.moveTo(arr, 0, 1), -1, "just after itself stays");
    compare(GridPlacement.moveTo(arr, 2, 0), 0);
    compare(arr, ["c", "b", "a"]);
    compare(GridPlacement.moveTo(arr, 7, 0), -1);
  }
}
