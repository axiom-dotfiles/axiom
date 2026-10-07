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

  function test_cards() {
    compare(GridPlacement.cards(4), "1");
    compare(GridPlacement.cards(2), "½");
    compare(GridPlacement.cards(5), "1¼");
    compare(GridPlacement.cards(11), "2¾");
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

  function p(x, y, w, h) {
    return at(x, y, w, h).place;
  }

  function test_normalize_hold() {
    const modules = [at(2, 3, 1, 1), at(4, 5, 1, 1)];
    compare(GridPlacement.normalize(modules, {
      "y": true
    }), {
      "x": 2,
      "y": 0
    }, "a gap before them stays on a held axis");
    compare(modules[0].place, p(0, 3, 1, 1));
    const negative = [at(0, -2, 1, 1)];
    compare(GridPlacement.normalize(negative, {
      "y": true
    }), {
      "x": 0,
      "y": -2
    }, "but nothing stays negative");
  }

  function test_clearOf() {
    verify(GridPlacement.clearOf([p(0, 0, 2, 2)], p(2, 0, 1, 1), -1, null));
    verify(!GridPlacement.clearOf([p(0, 0, 2, 2)], p(1, 1, 1, 1), -1, null));
    verify(GridPlacement.clearOf([p(0, 0, 2, 2)], p(1, 1, 1, 1), 0, null), "its own place ignored");
    verify(GridPlacement.clearOf([null], p(-2, -1, 1, 1), -1, null), "negative without an area");
    verify(!GridPlacement.clearOf([], p(-1, 0, 1, 1), -1, {
      "cols": 4,
      "rows": 4
    }), "outside the area");
  }

  function test_push() {
    const down = {
      "x": 0,
      "y": 1
    };
    // A column of three: a new module on top pushes all of them down
    const column = [p(0, 0, 2, 2), p(0, 2, 2, 2), p(0, 4, 2, 2)];
    compare(GridPlacement.push(column, -1, p(0, 0, 2, 1), down, null), [p(0, 1, 2, 2), p(0, 3, 2, 2), p(0, 5, 2, 2), p(0, 0, 2, 1)]);
    compare(column[0], p(0, 0, 2, 2), "the input isn't changed");
    // Only what's hit moves
    compare(GridPlacement.push([p(0, 0, 2, 2), p(4, 0, 2, 2)], -1, p(0, 1, 1, 1), down, null), [p(0, 2, 2, 2), p(4, 0, 2, 2), p(0, 1, 1, 1)]);
    // A move: its old place is free
    compare(GridPlacement.push([p(0, 0, 2, 2), p(0, 2, 2, 2)], 1, p(0, 0, 2, 2), down, null), [p(0, 2, 2, 2), p(0, 0, 2, 2)]);
    // The other directions
    compare(GridPlacement.push([p(0, 0, 2, 2)], -1, p(0, 1, 2, 2), {
      "x": 0,
      "y": -1
    }, null), [p(0, -1, 2, 2), p(0, 1, 2, 2)]);
    compare(GridPlacement.push([p(0, 0, 2, 2)], -1, p(1, 0, 1, 1), {
      "x": 1,
      "y": 0
    }, null), [p(2, 0, 2, 2), p(1, 0, 1, 1)]);
    compare(GridPlacement.push([p(0, 0, 2, 2)], -1, p(1, 0, 1, 1), {
      "x": -1,
      "y": 0
    }, null), [p(-1, 0, 2, 2), p(1, 0, 1, 1)]);
    // Pushed into the module put (wider than what hit it): past it too
    compare(GridPlacement.push([p(0, 0, 1, 1), p(0, 1, 1, 1)], 0, p(0, 1, 1, 3), down, null), [p(0, 1, 1, 3), p(0, 4, 1, 1)]);
    // Out of a bounded area: refused
    compare(GridPlacement.push([p(0, 0, 4, 2), p(0, 2, 4, 2)], -1, p(0, 0, 4, 1), down, {
      "cols": 4,
      "rows": 4
    }), null);
    verify(GridPlacement.push([p(0, 0, 4, 2)], -1, p(0, 0, 4, 1), down, {
      "cols": 4,
      "rows": 4
    }) !== null);
  }

  function test_pushGroup() {
    const down = {
      "x": 0,
      "y": 1
    };
    // Two side by side moved onto a wide one: it goes under both
    compare(GridPlacement.pushGroup([p(0, 0, 4, 1), p(0, 2, 2, 1), p(2, 2, 2, 1)], [[1, p(0, 0, 2, 1)], [2, p(2, 0, 2, 1)]], down, null), [p(0, 1, 4, 1), p(0, 0, 2, 1), p(2, 0, 2, 1)]);
    // Pushed into the lower of a group: past it too
    compare(GridPlacement.pushGroup([p(0, 0, 1, 1), p(5, 5, 1, 1), p(5, 6, 1, 1)], [[1, p(0, 0, 1, 1)], [2, p(0, 1, 1, 1)]], down, null), [p(0, 2, 1, 1), p(0, 0, 1, 1), p(0, 1, 1, 1)]);
  }

  function test_cover() {
    compare(GridPlacement.cover([p(1, 1, 1, 1), null, p(3, 0, 2, 4)]), p(1, 0, 4, 4));
    compare(GridPlacement.cover([]), null);
  }

  function test_fitPlace() {
    // A 2 × 2 hole at (2, 0) between two columns
    const places = [p(0, 0, 2, 4), p(4, 0, 2, 4)];
    const area = {
      "cols": 6,
      "rows": 2
    };
    compare(GridPlacement.fitPlace(places, {
      "x": 3,
      "y": 1
    }, [4, 4], [1, 1], area), p(2, 0, 2, 2), "shrinks into the hole");
    compare(GridPlacement.fitPlace(places, {
      "x": 0,
      "y": 0
    }, [4, 4], [1, 1], area), null, "the cell is taken");
    compare(GridPlacement.fitPlace(places, {
      "x": 3,
      "y": 1
    }, [4, 4], [3, 3], area), null, "smaller than the least size");
    // Room enough: its full size, centred on the cell
    compare(GridPlacement.fitPlace([], {
      "x": 5,
      "y": 5
    }, [4, 2], [1, 1], null), p(4, 5, 4, 2));
    // Of equal areas, the one shaped like what's wanted: a 4 × 1 strip
    // row free above a module 2 wide, wanting 4 × 2
    compare(GridPlacement.fitPlace([p(0, 1, 2, 1), p(2, 1, 2, 1)], {
      "x": 1,
      "y": 0
    }, [4, 2], [1, 1], {
      "cols": 4,
      "rows": 2
    }), p(0, 0, 4, 1));
  }

  function test_resizeFrom() {
    const place = p(2, 2, 2, 2);
    compare(GridPlacement.resizeFrom(place, "se", 1, 2), p(2, 2, 3, 4));
    compare(GridPlacement.resizeFrom(place, "e", 1, 5), p(2, 2, 3, 2), "an edge moves one side");
    compare(GridPlacement.resizeFrom(place, "s", 5, 1), p(2, 2, 2, 3));
    compare(GridPlacement.resizeFrom(place, "nw", -1, -2), p(1, 0, 3, 4), "the bottom right stays");
    compare(GridPlacement.resizeFrom(place, "n", 0, 1), p(2, 3, 2, 1));
    compare(GridPlacement.resizeFrom(place, "w", -2, 0), p(0, 2, 4, 2));
    compare(GridPlacement.resizeFrom(place, "ne", 1, -1), p(2, 1, 3, 3));
    compare(GridPlacement.resizeFrom(place, "sw", 1, 1), p(3, 2, 1, 3));
    compare(GridPlacement.resizeFrom(place, "nw", 5, 5), p(3, 3, 1, 1), "never below one unit, never flipped");
    compare(GridPlacement.resizeFrom(place, "se", 50, 0), p(2, 2, 32, 2), "at most maxSpan");
  }

  function test_firstFreeIn() {
    compare(GridPlacement.firstFreeIn([], 2, 2, 4, 4), at(0, 0, 2, 2).place);
    compare(GridPlacement.firstFreeIn([at(0, 0, 2, 2)], 2, 2, 4, 4), at(2, 0, 2, 2).place);
    compare(GridPlacement.firstFreeIn([at(0, 0, 4, 2)], 2, 2, 4, 4), at(0, 2, 2, 2).place);
    compare(GridPlacement.firstFreeIn([at(0, 0, 4, 4)], 1, 1, 4, 4), null);
    compare(GridPlacement.firstFreeIn([], 5, 1, 4, 4), null);
  }

  function test_scalePlace() {
    compare(GridPlacement.scalePlace(at(1, 2, 3, 4).place, true), at(2, 4, 6, 8).place);
    compare(GridPlacement.scalePlace(at(0, 0, 20, 1).place, true), at(0, 0, 32, 2).place);
    compare(GridPlacement.scalePlace(at(2, 4, 6, 8).place, false), at(1, 2, 3, 4).place);
    // Odd edges round, so neighbours still meet
    compare(GridPlacement.scalePlace(at(0, 0, 3, 1).place, false), at(0, 0, 2, 1).place);
    compare(GridPlacement.scalePlace(at(3, 0, 3, 1).place, false), at(2, 0, 1, 1).place);
    compare(GridPlacement.scalePlace(at(1, 1, 1, 1).place, false), at(1, 1, 1, 1).place);
  }

  function test_within() {
    verify(GridPlacement.within(at(0, 0, 4, 4).place, 4, 4));
    verify(GridPlacement.within(at(2, 3, 2, 1).place, 4, 4));
    verify(!GridPlacement.within(at(3, 0, 2, 1).place, 4, 4));
    verify(!GridPlacement.within(at(0, 4, 1, 1).place, 4, 4));
    verify(!GridPlacement.within(null, 4, 4));
  }

  function test_latticeUnit() {
    // 16 × 9 on 2560 × 1440 with 20 px margins: height decides
    const card = GridPlacement.latticeUnit(16, 9, 2560, 1440, 20);
    const unit = GridPlacement.unitOf(card);
    verify(Math.abs(unit - (1440 - 40 - 8 * 20) / 9) < 0.3);
    const sizes = GridPlacement.trackSizes({
      "cols": 16,
      "rows": 9
    }, card, {
      "width": 2520,
      "height": 1400
    });
    compare(Math.round(sizes.width), 2520);
    compare(Math.round(sizes.height), 1400);
    // A portrait screen: width decides
    const portrait = GridPlacement.unitOf(GridPlacement.latticeUnit(16, 9, 1080, 1920, 20));
    verify(Math.abs(portrait - (1080 - 40 - 15 * 20) / 16) < 0.3);
  }

  function test_screenGrid() {
    compare(GridPlacement.screenGrid({
      "columns": 16,
      "rows": 9
    }), {
      "cols": 16,
      "rows": 9
    });
    compare(GridPlacement.screenGrid({
      "columns": 16,
      "rows": 9,
      "fineGrid": true
    }), {
      "cols": 32,
      "rows": 18
    });
    compare(GridPlacement.screenGrid(null), {
      "cols": 0,
      "rows": 0
    });
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

  // A 500 px card's unit is 110 px, a step (unit + gap) 130 px. A 1000 px
  // edge with 10 px pads holds 7 cells (890 px), centred from 55 px
  function lattice(shift) {
    return GridPlacement.menuLattice(1000, 500, 10, 10, shift);
  }

  function test_menuLattice() {
    compare(GridPlacement.stepOf(500), 130);
    const l = lattice(0);
    compare([l.origin, l.step, l.cols, l.first, l.last, l.startPad], [55, 130, 7, 0, 6, 10]);
    compare([lattice(40).origin, lattice(40).first, lattice(40).last], [95, 0, 6], "moved, every cell still inside");
    compare(lattice(70).last, 5, "moved past the end: the last cell drops out");
    compare(lattice(-50).first, 1, "and past the start");
    compare(GridPlacement.menuLattice(910, 500, 10, 10, 0).cols, 7, "a room exactly 7 cells long holds 7");
  }

  function test_alongStart() {
    const l = lattice(0);
    compare(GridPlacement.alongStart(l, 0, 2), 315, "centred: cell 2 of 7");
    compare(GridPlacement.alongStart(l, 0, 3), 315, "one longer: the same cells, not half a cell over");
    compare(GridPlacement.alongStart(l, 0, 4), 185);
    compare(GridPlacement.alongStart(l, 1, 2), 445);
    compare(GridPlacement.alongStart(l, 10, 2), 705, "kept on the lattice");
    compare(GridPlacement.alongStart(l, -10, 2), 55);
    compare(GridPlacement.alongStart(lattice(40), 0, 2), 355, "a moved lattice moves it by px, on the same cell");
    compare(GridPlacement.alongStart(lattice(70), 10, 2), 125 + 4 * 130, "kept off a cell that dropped out");
    compare(GridPlacement.menuCell(l, 0, 8), null);
    compare(GridPlacement.alongStart(l, 0, 8), 10, "longer than the lattice: from its start");
  }

  function test_offsetRange() {
    const l = lattice(0);
    function range(units) {
      const r = GridPlacement.offsetRange(l, units);
      return [r.min, r.max];
    }
    compare(range(2), [-2, 3]);
    compare(range(7), [0, 0], "filling the lattice");
    compare(range(8), [0, 0], "longer than it");
    compare(GridPlacement.offsetFor(l, 4, 2), 2);
    for (let cell = 0; cell <= 5; cell++)
      compare(GridPlacement.menuCell(l, GridPlacement.offsetFor(l, cell, 2), 2), cell, `round trip at cell ${cell}`);
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
      "offset": -1,
      "modules": [at(0, 0, 2, 4)]
    };
    const place = GridPlacement.menuPlacement(menu, GridPlacement.bounds(menu.modules), 500, frame, 1920, 1080);
    // Two units across (240), four along (500). The edge holds 8 cells
    // from 30 px: centred is cell 2, one before it cell 1, at 160
    compare([place.along, place.across, place.length, place.depth, place.edgeLength], [160, 20, 500, 240, 1080]);
    compare([place.units, place.cell, place.lattice.origin], [4, 1, 30]);
    compare(GridPlacement.menuReservedDepth(place), 268, "across + depth + after");
    frame.reserves = false;
    compare(GridPlacement.menuReservedDepth(place), 5, "a floating menu: what it sits past");
    const onScreen = GridPlacement.menuOnScreen(menu, place, 500);
    // Against the right edge: 1920 - 20 - 240 = 1660
    compare(r4(onScreen.rect), [1652, 152, 256, 516], "the modules plus `after` all round");
    compare(r4(onScreen.modules[0].rect), [1660, 160, 240, 500]);
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
    compare(r4({
      "x": onScreen.view.x,
      "y": onScreen.view.y,
      "width": onScreen.view.w,
      "height": onScreen.view.h
    }), [-1.5, -3, 12, 10], "the view: the screen (and the grid below it) and a unit round, in fractions");
  }

  function test_canvas_geometry() {
    const extent = {
      "leadCols": 1,
      "leadRows": 1,
      "cols": 10,
      "rows": 6,
      "view": {
        "x": -1,
        "y": -1,
        "w": 10,
        "h": 6
      }
    };
    // A step is 130 px at the reference size: 1300 × 780 fits at 0.5
    const fit = GridPlacement.canvasFit(extent, 650, 390, 0.6);
    compare([fit.scale, fit.step, fit.gap, fit.unitSize], [0.5, 65, 10, 55]);
    compare([fit.originX, fit.originY], [70, 70], "centred, a lead unit in (plus half a gap)");
    compare(GridPlacement.canvasFit(extent, 6500, 3900, 0.6).scale, 0.6, "at most maxScale");
    // The screen stays put on the canvas as the grid moves on it
    const screenAt = boxX => {
      const box = {
        "x": boxX,
        "y": -2,
        "w": 10,
        "h": 4
      };
      const at = GridPlacement.canvasScreenRect(GridPlacement.canvasFit(GridPlacement.canvasExtent({
        "cols": 2,
        "rows": 2
      }, box, 1, 3), 650, 390, 0.6), box);
      return r4(at);
    };
    compare(screenAt(-3.5), screenAt(-4), "half a unit along");
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
    const fitted = GridPlacement.trackSizes({
      "cols": 8,
      "rows": 4
    }, 500, {
      "height": 380,
      "fit": true
    });
    compare(fitted.unitH, 80, "fit shrinks to the room");
    compare(fitted.height, 380);
    compare(fitted.unitW, 110, "only the fitted axis");
    const floored = GridPlacement.trackSizes({
      "cols": 8,
      "rows": 4
    }, 500, {
      "height": 100,
      "fit": true
    });
    compare(floored.unitH, 55, "fit stops at half a unit");
    compare(GridPlacement.trackSizes({
      "cols": 8,
      "rows": 4
    }, 500, {
      "height": 1020,
      "fit": true
    }).unitH, 240, "fit grows as stretch does");
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
