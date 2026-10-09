pragma Singleton
import QtQuick
import Quickshell.Io

import qs.components.methods

/**
 * Every popout showing, where it is, and which gives way to which.
 *
 * Each popout host (bar popouts, edge popouts: OSDs, floating edge menus,
 * the attached launcher; docks, the floating launcher) holds a
 * `PopoutClaim`, which registers here once its content is placed and it
 * wants to show, with its footprint: the rects it covers in screen px,
 * fillets included (SurfaceOutline.footprint). One that claims closes only
 * what its footprint overlaps, by rank (PopoutGeometry.ranks, lowest
 * first: pinned, dock, osd, bar, menu, launcher): lower and equal ones go,
 * a higher one refuses it. Residents (docks, pinned or previewing menus)
 * give way instead of closing, and come back once nothing covers them.
 *
 * `entries` is the location report: one plain object per registered
 * popout, { id, kind, screen, edge, barId, parentId, pinned, resident,
 * phase ("open" | "yielded"), footprint }.
 */
QtObject {
  id: root

  property var entries: []
  // id -> PopoutClaim
  property var _claims: ({})

  function entry(id) {
    return root.entries.find(e => e.id === id) ?? null;
  }

  // What shows on a screen (a ShellScreen or its name)
  function popoutsOn(screen) {
    const name = typeof screen === "string" ? screen : screen?.name ?? "";
    return root.entries.filter(e => e.screen === name && e.phase === "open");
  }

  function _entryOf(c, phase) {
    return {
      "id": c.key,
      "kind": c.kind,
      "screen": c.screen,
      "edge": c.edge,
      "barId": c.barId,
      "parentId": c.parentKey,
      "pinned": c.pinned,
      "resident": c.resident,
      "phase": phase,
      "footprint": c.footprint
    };
  }

  function _put(c, phase) {
    const others = root.entries.filter(e => e.id !== c.key);
    root._claims[c.key] = c;
    root.entries = others.concat([root._entryOf(c, phase)]);
    c._state = phase;
  }

  function _setPhase(id, phase) {
    const c = root._claims[id];
    if (!c)
      return;
    root.entries = root.entries.map(e => e.id === id ? Object.assign({}, e, {
        "phase": phase
      }) : e);
    c._state = phase;
  }

  // Applies a resolution's evictions and yields. The hosts close a turn
  // later: closing releases their claims, which would change `entries`
  // while this is still going through them.
  function _apply(r) {
    for (const id of r.yield)
      root._setPhase(id, "yielded");
    for (const id of r.evict) {
      const c = root._claims[id];
      if (!c)
        continue;
      root._drop(id);
      Qt.callLater(() => c.evicted());
    }
  }

  function _drop(id) {
    const c = root._claims[id];
    if (c)
      c._state = "";
    delete root._claims[id];
    root.entries = root.entries.filter(e => e.id !== id);
  }

  // A claim asks to show: true if it may. Refused, a resident waits
  // yielded; any other is told (`refused`) and dropped.
  function claim(c, resuming) {
    const r = PopoutGeometry.resolve(root.entries, Object.assign(root._entryOf(c, "open"), {
      "resuming": !!resuming
    }));
    if (!r.allowed) {
      if (c.resident) {
        root._put(c, "yielded");
      } else {
        root._drop(c.key);
        Qt.callLater(() => c.refused());
      }
      return false;
    }
    root._put(c, "open");
    root._apply(r);
    return true;
  }

  // A registered claim changed (its footprint, pin or residence): showing,
  // it closes what it now covers below it (it grew into it), and tolerates
  // what's above; yielded, it may come back
  function update(c) {
    if (!root._claims[c.key])
      return;
    if (c._state === "yielded") {
      // No longer resident (unpinned while away): it closes, as it would
      // have when covered
      if (!c.resident) {
        root._drop(c.key);
        Qt.callLater(() => c.evicted());
        return;
      }
      root._put(c, "yielded");
      root._resume();
      return;
    }
    const r = PopoutGeometry.resolve(root.entries, root._entryOf(c, "open"));
    root._put(c, "open");
    if (r.allowed)
      root._apply(r);
    // Ranked lower now (a pinned one let go), what it held off may be back
    root._resume();
  }

  // A claim no longer shows: anything it held off may come back
  function release(c) {
    if (!root._claims[c.key] || root._claims[c.key] !== c)
      return;
    root._drop(c.key);
    root._resume();
  }

  // Yielded residents with nothing over them any more come back
  function _resume() {
    for (const id of PopoutGeometry.resumable(root.entries)) {
      const c = root._claims[id];
      if (!c)
        continue;
      root._drop(id);
      root.claim(c, true);
    }
  }

  // `qs ipc call popouts list`: every popout registered, one per line, with
  // where it shows (its footprint's bounds, in screen px)
  property IpcHandler _ipc: IpcHandler {
    target: "popouts"

    function list(): string {
      return root.entries.map(e => {
        const fp = e.footprint ?? [];
        const x0 = Math.min(...fp.map(r => r.x)), y0 = Math.min(...fp.map(r => r.y));
        const x1 = Math.max(...fp.map(r => r.x + r.width)), y1 = Math.max(...fp.map(r => r.y + r.height));
        return `${e.id} ${e.kind} ${e.phase}${e.pinned ? " pinned" : ""}${e.resident ? " resident" : ""} ${e.screen} ${Math.round(x0)},${Math.round(y0)} ${Math.round(x1 - x0)}x${Math.round(y1 - y0)}`;
      }).join("\n");
    }
  }
}
