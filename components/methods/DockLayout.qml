pragma Singleton
import QtQuick

// Pure helpers for the dock: which apps it shows (pinned ones, then running
// ones), which window a click goes to, how big each icon is under the
// pointer, and whether a window covers it. Windows are hyprctl client
// objects ({ address, class, title, workspace, monitor, focusHistoryID, at,
// size, mapped, hidden }). No file access, processes or services.
QtObject {
  id: root

  // Whether a window counts on a dock: mapped, not hidden, and in its
  // scope ("all" | "monitor" | "workspace")
  function inScope(win, scope, monitorId, workspaceId) {
    if (!win || !win.mapped || win.hidden)
      return false;
    if (scope === "monitor")
      return win.monitor === monitorId;
    if (scope === "workspace")
      return win.workspace?.id === workspaceId;
    return true;
  }

  // The dock's items: [{ key, pinned, windows }], the pinned apps first in
  // their order, then (with showRunning) the apps of the other windows in
  // the order their first window appears. `resolve(win)` gives a window's
  // app key (its desktop entry id, else its class). Each item's windows
  // are most recently focused first.
  function buildItems(pinned, windows, resolve, showRunning) {
    const byKey = {};
    const order = [];
    for (const win of windows) {
      const key = resolve(win);
      if (!key)
        continue;
      if (!byKey[key]) {
        byKey[key] = [];
        order.push(key);
      }
      byKey[key].push(win);
    }
    const recent = list => list.slice().sort((a, b) => (a.focusHistoryID ?? 0) - (b.focusHistoryID ?? 0));
    const items = pinned.filter((key, i) => key && pinned.indexOf(key) === i).map(key => ({
          "key": key,
          "pinned": true,
          "windows": recent(byKey[key] ?? [])
        }));
    if (showRunning) {
      for (const key of order) {
        if (!pinned.includes(key))
          items.push({
            "key": key,
            "pinned": false,
            "windows": recent(byKey[key])
          });
      }
    }
    return items;
  }

  // The window a click on an app focuses: its most recent one, or, when
  // one of its windows is already focused, the next in a stable order (so
  // repeated clicks cycle through them). Empty when it has none.
  function clickTarget(windows, focusedAddress) {
    if (windows.length === 0)
      return "";
    const stable = windows.map(w => w.address).sort();
    const at = stable.indexOf(focusedAddress);
    if (at < 0)
      return windows[0].address;
    return stable[(at + 1) % stable.length];
  }

  // Each icon's size along the dock with the pointer at `pos` (pixels from
  // the start of the row as laid out at rest, null when it's elsewhere;
  // negative before the row's first icon, as the grown box reaches past
  // it): the icon under it `max`, falling off as a cosine to `base` at
  // `range` icons away. Distances are taken at rest, so the icon under the
  // pointer stays under it while the row grows.
  function magnifiedSizes(count, pos, base, max, range, spacing) {
    const sizes = [];
    const step = base + spacing;
    for (let i = 0; i < count; i++) {
      if (pos === null || range <= 0 || max <= base) {
        sizes.push(base);
        continue;
      }
      const distance = Math.abs(pos - (i * step + base / 2)) / step;
      sizes.push(distance >= range ? base : base + (max - base) * (Math.cos(Math.PI * distance / range) + 1) / 2);
    }
    return sizes;
  }

  // Whether two rects ({ x, y, width, height }) overlap
  function overlaps(a, b) {
    return a.x < b.x + b.width && b.x < a.x + a.width && a.y < b.y + b.height && b.y < a.y + a.height;
  }

  // Whether any of the windows (in the same coordinates as `rect`, from
  // hyprctl's `at` and `size`) covers the rect
  function covered(rect, windows) {
    return windows.some(w => w.at && w.size && root.overlaps(rect, {
        "x": w.at[0],
        "y": w.at[1],
        "width": w.size[0],
        "height": w.size[1]
      }));
  }
}
