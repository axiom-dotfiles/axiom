pragma Singleton

import QtQuick

// Pure geometry for the workspace overview: a cols×rows board of monitor
// miniatures. Grid coordinates have (0, 0) at the first cell's corner; rects
// are { x, y, w, h } (actions live in HyprlandManager).
QtObject {
  id: root

  // The largest scale at which cols×rows monitors of monW×monH, `gap` apart,
  // fit in availW×availH
  function fitScale(availW, availH, monW, monH, gap, cols, rows) {
    if (monW <= 0 || monH <= 0)
      return 0.1;
    const sx = (availW - gap * (cols - 1)) / (monW * cols);
    const sy = (availH - gap * (rows - 1)) / (monH * rows);
    return Math.max(0.01, Math.min(sx, sy));
  }

  function cellRect(index, cellW, cellH, gap, cols) {
    return {
      x: (index % cols) * (cellW + gap),
      y: Math.floor(index / cols) * (cellH + gap),
      w: cellW,
      h: cellH
    };
  }

  // The cell index under a point, or -1 (gaps, outside the board, and the
  // unused end of a last row: `count` cells in all)
  function cellAt(x, y, cellW, cellH, gap, cols, count) {
    const col = Math.floor(x / (cellW + gap));
    const row = Math.floor(y / (cellH + gap));
    if (col < 0 || row < 0 || col >= cols || row * cols + col >= count)
      return -1;
    if (x - col * (cellW + gap) > cellW || y - row * (cellH + gap) > cellH)
      return -1;
    return row * cols + col;
  }

  // A hyprctl client's rect inside its cell. `at` is global layout
  // coordinates, so the monitor's origin comes off first.
  function windowRect(win, monitorX, monitorY, scale, cellW, cellH) {
    const w = Math.max(8, Math.min((win?.size?.[0] ?? 0) * scale, cellW));
    const h = Math.max(8, Math.min((win?.size?.[1] ?? 0) * scale, cellH));
    const x = ((win?.at?.[0] ?? 0) - monitorX) * scale;
    const y = ((win?.at?.[1] ?? 0) - monitorY) * scale;
    return {
      x: Math.min(Math.max(x, 0), cellW - w),
      y: Math.min(Math.max(y, 0), cellH - h),
      w: w,
      h: h
    };
  }

  function contains(r, x, y) {
    return x >= r.x && x <= r.x + r.w && y >= r.y && y <= r.y + r.h;
  }

  function _distance(r, x, y) {
    const dx = Math.max(r.x - x, 0, x - (r.x + r.w));
    const dy = Math.max(r.y - y, 0, y - (r.y + r.h));
    return dx * dx + dy * dy;
  }

  // The topmost window under a point: floating windows sit above tiled ones.
  // items: [{ address, floating, rect }] in grid coordinates.
  function windowAt(items, x, y) {
    let tiled = "";
    for (let i = items.length - 1; i >= 0; i--) {
      const item = items[i];
      if (!contains(item.rect, x, y))
        continue;
      if (item.floating)
        return item.address;
      if (tiled === "")
        tiled = item.address;
    }
    return tiled;
  }

  // Where dwindle tiles a window dropped at a point, as HyprlandManager's
  // placeWindow reproduces it: on the tiled window under the point (else the
  // nearest), side by side when that is wider than tall × multiplier, in the
  // half the point is in. items: that cell's other tiled windows. Returns
  // { address, side, rect: the half } or null for an empty workspace.
  function dropTarget(items, x, y, multiplier) {
    let best = null;
    let bestDistance = -1;
    for (const item of items) {
      const d = _distance(item.rect, x, y);
      if (best === null || d < bestDistance) {
        best = item;
        bestDistance = d;
      }
    }
    if (best === null)
      return null;
    const r = best.rect;
    if (r.w > r.h * multiplier) {
      const first = x < r.x + r.w / 2;
      return {
        address: best.address,
        side: first ? "left" : "right",
        rect: {
          x: first ? r.x : r.x + r.w / 2,
          y: r.y,
          w: r.w / 2,
          h: r.h
        }
      };
    }
    const first = y < r.y + r.h / 2;
    return {
      address: best.address,
      side: first ? "top" : "bottom",
      rect: {
        x: r.x,
        y: first ? r.y : r.y + r.h / 2,
        w: r.w,
        h: r.h / 2
      }
    };
  }

  // The edges a resize grabs from a press: those whose outer third it's in
  // (both near a corner), or the nearest one from the middle.
  function resizeEdges(r, x, y) {
    const edges = {
      left: x < r.x + r.w / 3,
      right: x > r.x + r.w * 2 / 3,
      top: y < r.y + r.h / 3,
      bottom: y > r.y + r.h * 2 / 3
    };
    if (edges.left || edges.right || edges.top || edges.bottom)
      return edges;
    const distances = {
      left: x - r.x,
      right: r.x + r.w - x,
      top: y - r.y,
      bottom: r.y + r.h - y
    };
    const nearest = Object.keys(distances).reduce((a, b) => distances[a] <= distances[b] ? a : b);
    edges[nearest] = true;
    return edges;
  }

  // Stable order for assigning workspace-id blocks to monitors (grid and
  // perMonitor layouts): the primary monitor first (matched by `name`, as
  // General.primaryMonitor is stored/matched elsewhere), then the rest by
  // `key` — a caller-supplied stable identity (HyprlandManager fills it with
  // MonitorLayout.outputId, the same "follows the monitor across ports"
  // identity monitor profiles use). Hyprland.monitors.values' own order can
  // change on a hotplug/reconnect/restart; `key`/`name` don't, so this can't
  // reshuffle who owns which ids the way raw discovery order did.
  // monitors: [{ id, name, key, x, y }, ...], any order.
  function orderMonitors(monitors, primaryName) {
    const list = (monitors ?? []).slice();
    const isPrimary = m => !!primaryName && m.name === primaryName;
    const primary = list.filter(isPrimary);
    const rest = list.filter(m => !isPrimary(m));
    rest.sort((a, b) => String(a.key ?? a.name).localeCompare(String(b.key ?? b.name)));
    return primary.concat(rest);
  }
}
