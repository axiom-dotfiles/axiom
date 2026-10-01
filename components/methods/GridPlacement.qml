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
  // The largest a module's w or h may be (the schema's GridPlace maximum)
  readonly property int maxSpan: 32

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

  // How many grid units (fractional) of card size `unit` span `length` px
  function unitsAlong(length, unit) {
    return Math.max(0, (length + root.cardSpacing) / (root.unitOf(unit) + root.cardSpacing));
  }

  // One grid unit plus the gap after it, in px, at card size `unit`
  function stepOf(unit) {
    return root.unitOf(unit) + root.cardSpacing;
  }

  // Where an edge menu's modules (`length` px along the edge) start along
  // an edge `edgeLength` px long, in px from its start: `offset` grid units
  // in from the anchor `align` ("start" | "end"), or from the middle
  // ("center", positive towards the end), and kept between `startPad` and
  // `endPad` from the ends (a menu longer than the room starts at
  // `startPad`)
  function alongStart(align, offset, length, edgeLength, unit, startPad, endPad) {
    const step = root.stepOf(unit) * (offset ?? 0);
    const at = align === "start" ? startPad + step : align === "end" ? edgeLength - endPad - length - step : (edgeLength - length) / 2 + step;
    return Math.max(startPad, Math.min(at, edgeLength - endPad - length));
  }

  // The anchor for modules starting `start` px along the edge (see
  // alongStart), with the whole grid units from it: { align, offset }.
  // Within half a unit of an anchor they snap to it (flush, or centred);
  // otherwise they keep `current` (an align), so moving them by whole
  // units keeps them exactly where they're put. Without `current`, the
  // nearest anchor. Halfway between two whole units (a centred run that
  // grew or shrank by an odd number of units) the offset rounds towards
  // `currentOffset`, so growing and shrinking back returns it where it was.
  function anchorFor(start, length, edgeLength, unit, startPad, endPad, current, currentOffset) {
    const step = root.stepOf(unit);
    const units = {
      "start": (start - startPad) / step,
      "end": (edgeLength - endPad - length - start) / step,
      "center": (start - (edgeLength - length) / 2) / step
    };
    const nearest = ["start", "end", "center"].reduce((best, align) => Math.abs(units[align]) < Math.abs(units[best]) ? align : best, "start");
    const align = Math.abs(units[nearest]) < 0.5 || !(current in units) ? nearest : current;
    const raw = units[align];
    const towards = currentOffset ?? 0;
    const half = Math.abs(Math.abs(raw % 1) - 0.5) < 0.001;
    const offset = half ? (Math.abs(Math.floor(raw) - towards) <= Math.abs(Math.ceil(raw) - towards) ? Math.floor(raw) : Math.ceil(raw)) : Math.round(raw);
    return {
      "align": align,
      "offset": align === "center" ? offset : Math.max(0, offset)
    };
  }

  // The screen (`width` × `height` px) around an edge menu with modules
  // reaching `bounds` (at card size `unit`) on `edge` ("Left" | "Right" |
  // "Top" | "Bottom"), starting `along` px along the edge and `across` px
  // in from it. In grid units from the menu's grid origin, as the editor
  // draws it (its sides midway in the gaps): { x, y, w, h }.
  function screenBox(width, height, unit, bounds, edge, along, across) {
    const vertical = edge === "Left" || edge === "Right";
    const step = root.stepOf(unit);
    const thick = vertical ? bounds.cols : bounds.rows;
    const thickPx = thick > 0 ? thick * step - root.cardSpacing : 0;
    const acrossLen = vertical ? width : height;
    // The screen's start, in px from the grid's origin
    const alongFrom = -along;
    const acrossFrom = edge === "Right" || edge === "Bottom" ? thickPx + across - acrossLen : -across;
    const half = root.cardSpacing / 2;
    return vertical ? {
      "x": (acrossFrom + half) / step,
      "y": (alongFrom + half) / step,
      "w": width / step,
      "h": height / step
    } : {
      "x": (alongFrom + half) / step,
      "y": (acrossFrom + half) / step,
      "w": width / step,
      "h": height / step
    };
  }

  // A place as the [x, y, w, h] rect modules get as `slotRect`
  function rectOf(place) {
    return [place?.x ?? 0, place?.y ?? 0, place?.w ?? 2, place?.h ?? 2];
  }

  // A rect's shape: "square" while its longer side is under 1.5 times the
  // shorter (so 4 × 3 and 5 × 4 are square), else "horizontal" or
  // "vertical". Modules pick their orientation from it; any module takes
  // any size
  function slotShape(rect) {
    const w = rect[2], h = rect[3];
    return Math.max(w, h) < Math.min(w, h) * 1.5 ? "square" : w > h ? "horizontal" : "vertical";
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
  // Returns the shift taken off, { x, y } (0, 0 when nothing moved).
  function normalize(modules) {
    const placed = (modules ?? []).filter(module => module?.place);
    if (placed.length === 0)
      return {
        "x": 0,
        "y": 0
      };
    const minX = Math.min(...placed.map(module => module.place.x));
    const minY = Math.min(...placed.map(module => module.place.y));
    placed.forEach(module => {
      module.place.x -= minX;
      module.place.y -= minY;
    });
    return {
      "x": minX,
      "y": minY
    };
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
