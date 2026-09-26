pragma Singleton
import QtQuick

import qs.config
import qs.components.methods

/* OverlayManager holds the overlay editor's working copy of Overlay.views
 * (the editor is the pinned last page). Edits only affect localViews and
 * the editor's canvas; the real overlay pages and config.json are
 * untouched until saveChanges(). Mirrors BarManager.
 *
 * Also keeps the page's own state (selected page and slot), since the
 * page is unloaded whenever the overlay closes.
 *
 * Drop places: { kind: "column", column, index } inserts into a column
 * before its cell `index`; { kind: "gap", index } makes a new column
 * before column `index`. Indices are counted as if whatever moves were
 * still in place, so dropping a thing just after itself leaves it there. */
QtObject {
  id: root

  property ConfigDraft _draft: ConfigDraft {
    id: draft
    path: ["Overlay", "views"]
  }
  readonly property alias localViews: draft.local
  readonly property alias savedViews: draft.saved
  readonly property alias isDirty: draft.isDirty
  property int selectedViewIndex: 0
  // { column, cell, slot } of the selection in the selected page, slot ""
  // when it's the cell itself; null for none
  property var selected: null

  // Why the draft can't be saved as is (empty = savable)
  // Shapes are shown translated: I18n.tr("square") I18n.tr("horizontal") I18n.tr("vertical")
  readonly property var problems: {
    const out = [];
    (root.localViews ?? []).forEach((view, v) => {
      if (view.type !== "Custom")
        return;
      const name = view.name || I18n.tr("Page {0}", v + 1);
      if (!view.columns || view.columns.length === 0)
        out.push(I18n.tr("{0} has no columns", name));
      else
        view.columns.forEach((column, c) => {
          if (!column.cells || column.cells.length === 0)
            out.push(I18n.tr("{0}: column {1} has no cells", name, c + 1));
          (column.cells ?? []).forEach(cell => {
            const slots = OverlayConfig.layouts[cell.layout]?.slots ?? {};
            Object.keys(cell.slots ?? {}).forEach(slot => {
              const type = cell.slots[slot]?.type;
              if (type && slots[slot] && !OverlayConfig.fits(type, slots[slot]))
                out.push(I18n.tr("{0}: {1} doesn't fit a {2} slot", name, type, I18n.tr(OverlayConfig.slotShape(slots[slot]))));
              if (type && !OverlayConfig.allowedIn(type, "overlay"))
                out.push(I18n.tr("{0}: {1} only works in an edge menu", name, type));
            });
          });
        });
    });
    return out;
  }

  // Keeps the selected page where it still exists
  function loadConfig() {
    draft.load();
    root.selectedViewIndex = Math.max(0, Math.min(root.selectedViewIndex, (root.localViews?.length ?? 1) - 1));
    root.selected = null;
  }

  // Loads the draft unless it holds unsaved edits (the page is rebuilt
  // whenever the overlay reopens)
  function ensureLoaded() {
    if (!draft.isDirty)
      loadConfig();
  }

  // Call after mutating localViews in place
  function applyChanges() {
    draft.changed();
  }

  function _defaults(value, definition) {
    return SchemaValidation.applyDefaults(value, {
      "$ref": "#/definitions/" + definition
    }, ConfigManager.configSchema);
  }

  function _clone(value) {
    return JSON.parse(JSON.stringify(value ?? null));
  }

  // Moves arr[from] to insertion index `to`, counted as if it were still
  // in place. Returns the index it lands at, or -1 for no move.
  function _moveTo(arr, from, to) {
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

  // Whether a page differs from the saved page at the same position
  function viewChanged(index) {
    return JSON.stringify(root.localViews?.[index]) !== JSON.stringify(root.savedViews?.[index]);
  }

  // --- Pages ---

  function selectedView() {
    return root.localViews?.[root.selectedViewIndex] || null;
  }

  function selectView(index) {
    root.selectedViewIndex = index;
    root.selected = null;
  }

  function _newCell(layout) {
    return {
      "layout": layout ?? "Single",
      "slots": {}
    };
  }

  function addView(type) {
    const view = type === "Custom" ? {
      "type": "Custom",
      "name": I18n.tr("Page {0}", root.localViews.length + 1),
      "columns": [
        {
          "cells": [root._newCell()]
        }
      ]
    } : {
      "type": type
    };
    root.localViews.push(root._defaults(view, "OverlayView"));
    root.selectView(root.localViews.length - 1);
    applyChanges();
  }

  function removeView(index) {
    root.localViews.splice(index, 1);
    root.selectView(Math.max(0, Math.min(root.selectedViewIndex, root.localViews.length - 1)));
    applyChanges();
  }

  // The selected page stays selected wherever it ends up
  function moveView(from, to) {
    const selectedView = root.selectedView();
    if (root._moveTo(root.localViews, from, to) < 0)
      return;
    root.selectedViewIndex = Math.max(0, root.localViews.indexOf(selectedView));
    applyChanges();
  }

  function renameView(index, name) {
    const view = root.localViews[index];
    if (!view || view.name === name)
      return;
    view.name = name;
    applyChanges();
  }

  // --- Selection ---

  function select(c, k, slot) {
    root.selected = {
      "column": c,
      "cell": k,
      "slot": slot ?? ""
    };
  }

  function clearSelection() {
    root.selected = null;
  }

  function isSelected(c, k, slot) {
    const sel = root.selected;
    return sel !== null && sel.column === c && sel.cell === k && sel.slot === (slot ?? "");
  }

  function isCellSelected(c, k) {
    const sel = root.selected;
    return sel !== null && sel.column === c && sel.cell === k;
  }

  function selectedCell() {
    const sel = root.selected;
    return sel ? root._cell(sel.column, sel.cell) : null;
  }

  // The selected slot's module, or null (none, a cell, or an empty slot)
  function selectedModule() {
    const sel = root.selected;
    return sel && sel.slot !== "" ? root.slotModule(sel.column, sel.cell, sel.slot) : null;
  }

  // --- Structure (columns and cells of the selected page) ---

  function _columns() {
    return root.selectedView()?.columns ?? null;
  }

  function _cell(c, k) {
    return root._columns()?.[c]?.cells?.[k] ?? null;
  }

  function slotRect(c, k, slot) {
    return OverlayConfig.layouts[root._cell(c, k)?.layout]?.slots?.[slot] ?? null;
  }

  // Runs a structural edit of the selected page. The cells are tracked by
  // identity across it: the selection stays on its cell (or moves to
  // `focus`, a cell object, if given), and columns it empties are removed.
  // `edit` returns the cell to select, or undefined to keep the selection.
  function _restructure(edit) {
    const columns = root._columns();
    if (!columns)
      return;
    const sel = root.selected;
    const selectedCell = sel ? root._cell(sel.column, sel.cell) : null;
    const focus = edit(columns);
    if (focus === false)
      return; // nothing changed
    for (let c = columns.length - 1; c >= 0; c--) {
      if (!columns[c].cells || columns[c].cells.length === 0)
        columns.splice(c, 1);
    }
    const find = cell => {
      for (let c = 0; c < columns.length; c++) {
        const k = columns[c].cells.indexOf(cell);
        if (k >= 0)
          return [c, k];
      }
      return null;
    };
    const target = focus?.cell ?? selectedCell;
    const at = target ? find(target) : null;
    if (at)
      root.select(at[0], at[1], focus ? (focus.slot ?? "") : sel.slot);
    else
      root.selected = null;
    applyChanges();
  }

  // Puts `cell` at a drop place (see the top); the source column isn't
  // pruned yet, so gap indices still count it
  function _insertCell(columns, place, cell) {
    if (place.kind === "gap") {
      columns.splice(Math.max(0, Math.min(place.index, columns.length)), 0, {
        "cells": [cell]
      });
    } else {
      const cells = columns[place.column]?.cells;
      if (!cells)
        return false;
      cells.splice(Math.max(0, Math.min(place.index, cells.length)), 0, cell);
    }
    return true;
  }

  function moveColumn(from, to) {
    root._restructure(columns => root._moveTo(columns, from, to) < 0 ? false : undefined);
  }

  function removeColumn(c) {
    root._restructure(columns => {
      columns.splice(c, 1);
    });
  }

  // A new empty column holding one Single cell, at the end
  function addColumn() {
    root._restructure(columns => {
      const cell = root._newCell();
      columns.push({
        "cells": [cell]
      });
      return {
        "cell": cell
      };
    });
  }

  function addCell(place, layout) {
    root._restructure(columns => {
      const cell = root._newCell(layout);
      return root._insertCell(columns, place, cell) ? {
        "cell": cell
      } : false;
    });
  }

  // Where "add" puts a new cell: after the selected cell, else at the end
  // of the last column (or a new first column on an empty page)
  function _appendPlace() {
    const columns = root._columns() ?? [];
    const sel = root.selected;
    if (sel && root._cell(sel.column, sel.cell))
      return {
        "kind": "column",
        "column": sel.column,
        "index": sel.cell + 1
      };
    if (columns.length === 0)
      return {
        "kind": "gap",
        "index": 0
      };
    return {
      "kind": "column",
      "column": columns.length - 1,
      "index": columns[columns.length - 1].cells?.length ?? 0
    };
  }

  function appendCell(layout) {
    root.addCell(root._appendPlace(), layout);
  }

  function moveCell(c, k, place) {
    root._restructure(columns => {
      const cells = columns[c]?.cells;
      const cell = cells?.[k];
      if (!cell)
        return false;
      let index = place.index;
      if (place.kind === "column" && place.column === c) {
        if (index > k)
          index--;
        if (index === k)
          return false;
      }
      // Its own column's gaps, when it's alone in it: already there
      if (place.kind === "gap" && cells.length === 1 && (index === c || index === c + 1))
        return false;
      cells.splice(k, 1);
      root._insertCell(columns, Object.assign({}, place, {
        "index": index
      }), cell);
      return {
        "cell": cell,
        "slot": root.selected && root.selected.column === c && root.selected.cell === k ? root.selected.slot : ""
      };
    });
  }

  function duplicateCell(c, k) {
    root._restructure(columns => {
      const cells = columns[c]?.cells;
      if (!cells?.[k])
        return false;
      const copy = root._clone(cells[k]);
      cells.splice(k + 1, 0, copy);
      return {
        "cell": copy
      };
    });
  }

  function removeCell(c, k) {
    root._restructure(columns => {
      if (!columns[c]?.cells?.[k])
        return false;
      columns[c].cells.splice(k, 1);
    });
  }

  // Modules keep their slot where the new layout has one of that name;
  // the rest move to free slots they fit, in order (any left over are
  // dropped). The selection follows its module.
  function setCellLayout(c, k, layout) {
    const cell = root._cell(c, k);
    const slots = OverlayConfig.layouts[layout]?.slots;
    if (!cell || cell.layout === layout || !slots)
      return;
    const old = cell.slots ?? {};
    const kept = {};
    const leftovers = [];
    Object.keys(old).forEach(name => {
      if (name in slots)
        kept[name] = old[name];
      else
        leftovers.push(name);
    });
    const moved = {};
    leftovers.forEach(name => {
      const free = Object.keys(slots).find(slot => !kept[slot] && OverlayConfig.fits(old[name].type, slots[slot]));
      if (free) {
        kept[free] = old[name];
        moved[name] = free;
      }
    });
    cell.layout = layout;
    cell.slots = kept;
    const sel = root.selected;
    if (sel && sel.column === c && sel.cell === k && sel.slot !== "")
      root.select(c, k, (sel.slot in slots) ? sel.slot : (moved[sel.slot] ?? ""));
    applyChanges();
  }

  // --- Slots ---

  function slotModule(c, k, slot) {
    return root._cell(c, k)?.slots?.[slot] ?? null;
  }

  function _newModule(type) {
    return root._defaults({
      "type": type
    }, "OverlayModule");
  }

  // A new module (at its schema defaults) in a slot, replacing what's
  // there; refused where it doesn't fit
  function placeModule(type, c, k, slot) {
    const cell = root._cell(c, k);
    const rect = root.slotRect(c, k, slot);
    if (!cell || !rect || !OverlayConfig.fits(type, rect))
      return;
    if (!cell.slots)
      cell.slots = {};
    cell.slots[slot] = root._newModule(type);
    root.select(c, k, slot);
    applyChanges();
  }

  function clearSlot(c, k, slot) {
    const cell = root._cell(c, k);
    if (!cell?.slots?.[slot])
      return;
    delete cell.slots[slot];
    applyChanges();
  }

  // Whether the module at `from` can move to `to`: it must fit there, and
  // whatever it displaces must fit where it came from
  function canMoveModule(from, to) {
    const module = root.slotModule(from.column, from.cell, from.slot);
    const toRect = root.slotRect(to.column, to.cell, to.slot);
    if (!module || !toRect)
      return false;
    if (from.column === to.column && from.cell === to.cell && from.slot === to.slot)
      return true;
    const other = root.slotModule(to.column, to.cell, to.slot);
    return OverlayConfig.fits(module.type, toRect) && (!other || OverlayConfig.fits(other.type, root.slotRect(from.column, from.cell, from.slot)));
  }

  // Moves a module to another slot, swapping with any module there
  function moveModule(from, to) {
    if (from.column === to.column && from.cell === to.cell && from.slot === to.slot)
      return;
    if (!root.canMoveModule(from, to))
      return;
    const fromCell = root._cell(from.column, from.cell);
    const toCell = root._cell(to.column, to.cell);
    const module = fromCell.slots[from.slot];
    const other = toCell.slots?.[to.slot];
    if (!toCell.slots)
      toCell.slots = {};
    if (other)
      fromCell.slots[from.slot] = other;
    else
      delete fromCell.slots[from.slot];
    toCell.slots[to.slot] = module;
    root.select(to.column, to.cell, to.slot);
    applyChanges();
  }

  // A module in a new cell of its own (see OverlayConfig.bestLayoutFor)
  function _moduleCell(module) {
    const cell = root._newCell(OverlayConfig.bestLayoutFor(module.type));
    cell.slots.main = module;
    return cell;
  }

  function addModuleCell(type, place) {
    root._restructure(columns => {
      const cell = root._moduleCell(root._newModule(type));
      return root._insertCell(columns, place, cell) ? {
        "cell": cell,
        "slot": "main"
      } : false;
    });
  }

  // Adds a module in a new cell where appendCell would put one
  function appendModule(type) {
    root.addModuleCell(type, root._appendPlace());
  }

  // Takes a module out of its slot into a new cell of its own at `place`
  // (its old cell stays, with that slot empty)
  function extractModule(from, place) {
    root._restructure(columns => {
      const fromCell = columns[from.column]?.cells?.[from.cell];
      const module = fromCell?.slots?.[from.slot];
      if (!module)
        return false;
      delete fromCell.slots[from.slot];
      const cell = root._moduleCell(module);
      root._insertCell(columns, place, cell);
      return {
        "cell": cell,
        "slot": "main"
      };
    });
  }

  function updateModuleProperty(c, k, slot, key, value) {
    const module = root.slotModule(c, k, slot);
    if (!module)
      return;
    if (!module.properties)
      module.properties = {};
    module.properties[key] = value;
    applyChanges();
  }

  // --- Save / reset ---

  // Merged onto the latest real config; stays dirty if rejected
  function saveChanges() {
    if (root.problems.length > 0)
      return false;
    return draft.save();
  }

  function resetChanges() {
    loadConfig();
  }
}
