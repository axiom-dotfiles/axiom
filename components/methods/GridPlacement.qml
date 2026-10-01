pragma Singleton

import QtQuick

// Pure geometry of the module grid shared by overlay pages, edge menus and
// the layouts editor. Modules are placed on a grid of quarter cards: each
// has a `place` { x, y, w, h } in grid units, four to a card. Holes are
// allowed; modules never overlap. OverlayConfig wraps these with the schema's module info.
QtObject {
  id: root

  // Card grid constants: internal design values, not user settings.
  // cardUnit is the reference card size: the largest a card gets at 100%
  // (each overlay's OverlayGrid sizes its cards to its screen, up to this).
  readonly property int cardUnit: 500
  readonly property int cardSpacing: 20

  // A span of n grid units is n units plus the n - 1 gaps between them,
  // so span(4) is one card, span(2) half a card and span(8) two cards plus
  // the gap between them. `unit` is the card size (the reference cardUnit
  // unless given).
  function unitOf(unit) {
    return ((unit ?? root.cardUnit) - 3 * root.cardSpacing) / 4;
  }

  function span(n, unit) {
    return n * root.unitOf(unit) + (n - 1) * root.cardSpacing;
  }

  // A place as the [x, y, w, h] rect modules get as `slotRect`
  function rectOf(place) {
    return [place?.x ?? 0, place?.y ?? 0, place?.w ?? 2, place?.h ?? 2];
  }

  // A rect's shape: "square", "horizontal" or "vertical"
  function slotShape(rect) {
    return rect[2] === rect[3] ? "square" : rect[2] > rect[3] ? "horizontal" : "vertical";
  }

  // Whether something fitting `shapes` (a list of shapes) may take `rect`
  function fitsShapes(shapes, rect) {
    return shapes.includes(root.slotShape(rect));
  }

  // Whether `rect` is at least `minSize` ([w, h]; null for any size)
  function fitsSize(minSize, rect) {
    return !minSize || (rect[2] >= minSize[0] && rect[3] >= minSize[1]);
  }

  // How far the modules reach, in grid units
  function bounds(modules) {
    let cols = 0;
    let rows = 0;
    (modules ?? []).forEach(module => {
      const p = module?.place;
      if (!p)
        return;
      cols = Math.max(cols, p.x + p.w);
      rows = Math.max(rows, p.y + p.h);
    });
    return {
      "cols": cols,
      "rows": rows
    };
  }

  function overlaps(a, b) {
    return a.x < b.x + b.w && b.x < a.x + a.w && a.y < b.y + b.h && b.y < a.y + a.h;
  }

  // Whether `place` is on the grid and clear of every module but the one at
  // `ignore` (an index; -1 for none)
  function canPlace(modules, place, ignore) {
    if (!place || place.x < 0 || place.y < 0 || place.w < 1 || place.h < 1)
      return false;
    return !(modules ?? []).some((module, i) => i !== ignore && module?.place && root.overlaps(module.place, place));
  }

  // The first free w × h spot in reading order within the modules' bounds
  // (at least `minCols` wide), else to the right of them
  function firstFree(modules, w, h, minCols) {
    const b = root.bounds(modules);
    const cols = Math.max(b.cols, minCols ?? 0, w);
    for (let y = 0; y + h <= b.rows; y++) {
      for (let x = 0; x + w <= cols; x++) {
        const place = {
          "x": x,
          "y": y,
          "w": w,
          "h": h
        };
        if (root.canPlace(modules, place, -1))
          return place;
      }
    }
    if (b.cols === 0)
      return {
        "x": 0,
        "y": 0,
        "w": w,
        "h": h
      };
    // Below when the grid is wider than tall, else to the right
    return b.cols > b.rows * 2 ? {
      "x": 0,
      "y": b.rows,
      "w": w,
      "h": h
    } : {
      "x": b.cols,
      "y": 0,
      "w": w,
      "h": h
    };
  }

  // Shifts the modules (in place) so the topmost and leftmost touch 0.
  // Returns whether anything moved.
  function normalize(modules) {
    const placed = (modules ?? []).filter(module => module?.place);
    if (placed.length === 0)
      return false;
    const minX = Math.min(...placed.map(module => module.place.x));
    const minY = Math.min(...placed.map(module => module.place.y));
    if (minX === 0 && minY === 0)
      return false;
    placed.forEach(module => {
      module.place.x -= minX;
      module.place.y -= minY;
    });
    return true;
  }

  // The size of one grid unit across and down, and of the whole grid, for
  // `bounds` at card size `unit`. `stretch` ({ width, height }, either
  // optional) is room to grow into: that axis's units share it evenly. A
  // grid never shrinks below its natural size.
  function trackSizes(bounds, unit, stretch) {
    const size = root.unitOf(unit);
    const spacing = root.cardSpacing;
    const grow = (count, room) => count > 0 && room > 0 ? Math.max(size, (room - (count - 1) * spacing) / count) : size;
    const unitW = grow(bounds.cols, stretch?.width ?? 0);
    const unitH = grow(bounds.rows, stretch?.height ?? 0);
    return {
      "unitW": unitW,
      "unitH": unitH,
      "width": bounds.cols > 0 ? bounds.cols * unitW + (bounds.cols - 1) * spacing : 0,
      "height": bounds.rows > 0 ? bounds.rows * unitH + (bounds.rows - 1) * spacing : 0
    };
  }

  // A place's pixel rect for trackSizes' `sizes`
  function rectPx(place, sizes) {
    const spacing = root.cardSpacing;
    return {
      "x": place.x * (sizes.unitW + spacing),
      "y": place.y * (sizes.unitH + spacing),
      "width": place.w * sizes.unitW + (place.w - 1) * spacing,
      "height": place.h * sizes.unitH + (place.h - 1) * spacing
    };
  }

  // Moves arr[from] to insertion index `to`, counted as if it were still
  // in place. Returns the index it lands at, or -1 for no move.
  function moveTo(arr, from, to) {
    if (!arr || from < 0 || from >= arr.length)
      return -1;
    let at = Math.max(0, Math.min(to, arr.length));
    if (at > from)
      at--;
    if (at === from)
      return -1;
    const [item] = arr.splice(from, 1);
    arr.splice(at, 0, item);
    return at;
  }
}
