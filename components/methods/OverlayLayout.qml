pragma Singleton

import QtQuick

// Pure geometry of the overlay's card grid, shared by overlay pages, edge
// menus and their editors: cell layouts on a grid of half cards, how a
// column flows its cells, and the structural helpers the editors use.
// OverlayConfig wraps these with the schema's module info.
QtObject {
  id: root

  // Card grid constants: internal design values, not user settings.
  // cardUnit is the reference card size: the largest a card gets at 100%
  // (each overlay's OverlayGrid sizes its cards to its screen, up to this).
  readonly property int cardUnit: 500
  readonly property int cardSpacing: 20

  // Cell layouts, keyed by the `layout` name in config (keep in sync with
  // the OverlayCell enum in the schema). cols/rows are the cell's size in
  // half units; each slot is [col, row, colSpan, rowSpan] in half units.
  readonly property var layouts: ({
      "Single": {
        "cols": 2,
        "rows": 2,
        "slots": {
          "main": [0, 0, 2, 2]
        }
      },
      "Tall": {
        "cols": 2,
        "rows": 4,
        "slots": {
          "main": [0, 0, 2, 4]
        }
      },
      "Wide": {
        "cols": 4,
        "rows": 2,
        "slots": {
          "main": [0, 0, 4, 2]
        }
      },
      "Large": {
        "cols": 4,
        "rows": 4,
        "slots": {
          "main": [0, 0, 4, 4]
        }
      },
      "HalfWide": {
        "cols": 2,
        "rows": 1,
        "slots": {
          "main": [0, 0, 2, 1]
        }
      },
      "HalfTall": {
        "cols": 1,
        "rows": 2,
        "slots": {
          "main": [0, 0, 1, 2]
        }
      },
      "Grid2x2": {
        "cols": 2,
        "rows": 2,
        "slots": {
          "topLeft": [0, 0, 1, 1],
          "topRight": [1, 0, 1, 1],
          "bottomLeft": [0, 1, 1, 1],
          "bottomRight": [1, 1, 1, 1]
        }
      },
      "Vert1x1": {
        "cols": 2,
        "rows": 2,
        "slots": {
          "left": [0, 0, 1, 2],
          "right": [1, 0, 1, 2]
        }
      },
      "Vert1x2": {
        "cols": 2,
        "rows": 2,
        "slots": {
          "left": [0, 0, 1, 2],
          "topRight": [1, 0, 1, 1],
          "bottomRight": [1, 1, 1, 1]
        }
      },
      "Vert2x1": {
        "cols": 2,
        "rows": 2,
        "slots": {
          "topLeft": [0, 0, 1, 1],
          "bottomLeft": [0, 1, 1, 1],
          "right": [1, 0, 1, 2]
        }
      },
      "Horiz1x1": {
        "cols": 2,
        "rows": 2,
        "slots": {
          "top": [0, 0, 2, 1],
          "bottom": [0, 1, 2, 1]
        }
      },
      "Horiz1x2": {
        "cols": 2,
        "rows": 2,
        "slots": {
          "top": [0, 0, 2, 1],
          "bottomLeft": [0, 1, 1, 1],
          "bottomRight": [1, 1, 1, 1]
        }
      },
      "Horiz2x1": {
        "cols": 2,
        "rows": 2,
        "slots": {
          "topLeft": [0, 0, 1, 1],
          "topRight": [1, 0, 1, 1],
          "bottom": [0, 1, 2, 1]
        }
      }
    })

  // Cells are laid out on a grid of half cards: a span of n half units is
  // n halves plus the n - 1 gaps between them, so span(2) is one card and
  // span(4) is two cards plus the gap between them. `unit` is the card
  // size (the reference cardUnit unless given).
  function halfUnitOf(unit) {
    return ((unit ?? root.cardUnit) - root.cardSpacing) / 2;
  }

  function span(n, unit) {
    return n * root.halfUnitOf(unit) + (n - 1) * root.cardSpacing;
  }

  // A slot's shape, from its [col, row, colSpan, rowSpan] rect
  function slotShape(rect) {
    return rect[2] === rect[3] ? "square" : rect[2] > rect[3] ? "horizontal" : "vertical";
  }

  // Whether something fitting `shapes` (a list of slot shapes) may sit in
  // a slot of the given rect
  function fitsShapes(shapes, rect) {
    return shapes.includes(root.slotShape(rect));
  }

  // How a column flows its cells: left to right, wrapping at the widest
  // cell. Returns the size, the number of rows and each cell's
  // { x, y, width, height, row }, matching OverlayColumn. `extra`
  // ({ width, height }, either optional) grows every cell: each row gets
  // the extra width, split between its cells, and the extra height, split
  // evenly between the rows. `target` (the same shape) is room for cells
  // to grow into past that: a row's spare width goes to its `fillWidth`
  // cells, `fillHeight` cells take their row's height, and spare height
  // goes to the rows holding one, split evenly. Without either nothing
  // changes.
  function columnFlow(cells, unit, target, extra) {
    const spacing = root.cardSpacing;
    const sizes = (cells ?? []).map(cell => {
      const layout = root.layouts[cell?.layout] ?? root.layouts.Single;
      return [root.span(layout.cols, unit), root.span(layout.rows, unit)];
    });
    const naturalWidth = Math.max(0, ...sizes.map(size => size[0]));
    // Natural rows: which cells, their width and height
    const rows = [];
    let x = 0;
    sizes.forEach(([w, h], i) => {
      if (rows.length === 0 || (x > 0 && x + w > naturalWidth + 0.5)) {
        rows.push({
          "cells": [],
          "width": 0,
          "height": 0
        });
        x = 0;
      }
      const row = rows[rows.length - 1];
      row.cells.push(i);
      row.width = x + w;
      row.height = Math.max(row.height, h);
      x += w + spacing;
    });
    // Every cell grows by `extra`
    const extraWidth = rows.length > 0 ? Math.max(0, extra?.width ?? 0) : 0;
    const extraRowHeight = rows.length > 0 ? Math.max(0, extra?.height ?? 0) / rows.length : 0;
    const grown = i => [sizes[i][0] + extraWidth / rows.find(row => row.cells.includes(i)).cells.length, sizes[i][1] + extraRowHeight];
    rows.forEach(row => {
      row.width += extraWidth;
      row.height += extraRowHeight;
    });
    const width = naturalWidth + extraWidth;
    const fillsWidth = i => cells[i]?.fillWidth === true;
    const fillsHeight = i => cells[i]?.fillHeight === true;
    const naturalHeight = rows.reduce((sum, row) => sum + row.height, 0) + Math.max(0, rows.length - 1) * spacing;
    const fullWidth = rows.some(row => row.cells.some(fillsWidth)) ? Math.max(width, target?.width ?? 0) : width;
    const heightRows = rows.filter(row => row.cells.some(fillsHeight)).length;
    const spareHeight = heightRows > 0 ? Math.max(0, (target?.height ?? 0) - naturalHeight) : 0;
    const rects = [];
    let y = 0;
    rows.forEach((row, rowIndex) => {
      const widthFills = row.cells.filter(fillsWidth).length;
      const rowHeight = row.height + (row.cells.some(fillsHeight) ? spareHeight / heightRows : 0);
      const fillWidth = widthFills > 0 ? (fullWidth - row.width) / widthFills : 0;
      let cx = 0;
      row.cells.forEach(i => {
        const [cellWidth, cellHeight] = grown(i);
        const w = cellWidth + (fillsWidth(i) ? fillWidth : 0);
        rects[i] = {
          "x": cx,
          "y": y,
          "width": w,
          "height": fillsHeight(i) ? rowHeight : cellHeight,
          "row": rowIndex
        };
        cx += w + spacing;
      });
      y += rowHeight + spacing;
    });
    return {
      "width": fullWidth,
      "height": Math.max(0, y - spacing),
      "rows": rows.length,
      "rects": rects
    };
  }

  // The length of columns laid side by side (their columnFlows), along a
  // `vertical` edge (the tallest) or a horizontal one (end to end with the
  // spacing between), grown by `extra` when there are any
  function columnsLength(flows, vertical, extra) {
    if (flows.length === 0)
      return 0;
    const grow = Math.max(0, extra ?? 0);
    if (vertical)
      return Math.max(...flows.map(flow => flow.height)) + grow;
    return flows.reduce((sum, flow) => sum + flow.width, 0) + (flows.length - 1) * root.cardSpacing + grow;
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

  // A cell's modules under a new layout's slots: each keeps its slot where
  // the new layout has one of that name; the rest move, in order, to free
  // slots where `fits(module, rect)` allows (any left over are dropped).
  // Returns { slots, moved: { oldName: newName } }.
  function remapSlots(oldSlots, newSlots, fits) {
    const old = oldSlots ?? {};
    const kept = {};
    const leftovers = [];
    Object.keys(old).forEach(name => {
      if (name in newSlots)
        kept[name] = old[name];
      else
        leftovers.push(name);
    });
    const moved = {};
    leftovers.forEach(name => {
      const free = Object.keys(newSlots).find(slot => !kept[slot] && fits(old[name], newSlots[slot]));
      if (free) {
        kept[free] = old[name];
        moved[name] = free;
      }
    });
    return {
      "slots": kept,
      "moved": moved
    };
  }
}
