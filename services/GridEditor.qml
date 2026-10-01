pragma ComponentBehavior: Bound
import QtQuick

import qs.config
import qs.components.methods

/* Editing of one grid of modules (each with a `place` { x, y, w, h } in
 * quarter cards), shared by the layouts editor's overlay pages and edge
 * menus. Not a singleton: OverlayManager and EdgeMenuManager each own one,
 * point `modulesOf` at the live modules array in their draft and run their
 * draft's changed() on `edited`.
 *
 * Also holds the selection, since the editor page is unloaded whenever the
 * overlay closes. Every edit keeps the selection on its module and shifts
 * the grid so its top left module sits at 0, 0: a place left of or above
 * the grid (negative x or y) makes room there. */
QtObject {
  id: root

  // Returns the modules array being edited (mutated in place), or null
  property var modulesOf: () => null
  // Where the modules are shown: "overlay" or "edgeMenu" (x-hosts)
  property string host: "overlay"
  // What's being edited (a page, a menu): forms are rebuilt when it changes
  property string scopeKey: ""

  // Called in every edit, as the grid shifts back to 0, 0: with the shift
  // taken off ({ x, y } grid units, a place left of or above the grid
  // being negative) and a copy of the modules before the edit
  property var shifted: (shift, before) => {}

  // After every edit: the owner marks its draft changed
  signal edited

  // Index of the selected module, -1 for none
  readonly property int selected: root._selected
  property int _selected: -1

  // Why these modules can't be saved as is, each prefixed with `name`
  function problemsFor(modules, name) {
    const out = [];
    (modules ?? []).forEach((module, i) => {
      const type = module?.type;
      if (type && !OverlayConfig.allowedIn(type, root.host))
        out.push(root.host === "overlay" ? I18n.tr("{0}: {1} only works in an edge menu", name, type) : I18n.tr("{0}: {1} only works on an overlay page", name, type));
      if (!GridPlacement.canPlace(modules.slice(0, i), module?.place, -1))
        out.push(I18n.tr("{0}: {1} overlaps another module", name, type));
    });
    return out;
  }

  // --- Selection ---

  function select(index) {
    root._selected = index;
  }

  function clearSelection() {
    root._selected = -1;
  }

  function module(index) {
    return root._modules()?.[index] ?? null;
  }

  function selectedModule() {
    return root.module(root.selected);
  }

  // --- Reading ---

  function _modules() {
    return root.modulesOf() ?? null;
  }

  // Whether `place` is clear of every module but the one at `ignore`,
  // negative x and y allowed (the grid shifts to make room)
  function _clear(modules, place, ignore) {
    return place.w >= 1 && place.h >= 1 && !(modules ?? []).some((module, i) => i !== ignore && module?.place && GridPlacement.overlaps(module.place, place));
  }

  function _place(x, y, w, h) {
    return {
      "x": x,
      "y": y,
      "w": w,
      "h": h
    };
  }

  // The module whose place is exactly `place` (a swap partner), else -1
  function _sameSpot(modules, place, ignore) {
    return (modules ?? []).findIndex((module, i) => i !== ignore && module?.place && module.place.x === place.x && module.place.y === place.y && module.place.w === place.w && module.place.h === place.h);
  }

  // Whether a new module of `type` may be added at `place` ({ x, y, w, h })
  function canAdd(type, place) {
    return OverlayConfig.allowedIn(type, root.host) && root._clear(root._modules(), place, -1);
  }

  // Whether module `index` may move with its top left to x, y: somewhere
  // clear, or exactly onto a module of its size (they swap)
  function canMove(index, x, y) {
    const modules = root._modules();
    const module = modules?.[index];
    if (!module)
      return false;
    const place = root._place(x, y, module.place.w, module.place.h);
    return root._clear(modules, place, index) || root._sameSpot(modules, place, index) >= 0;
  }

  // Whether module `index` may take the size w × h (top left kept)
  function canResize(index, w, h) {
    const modules = root._modules();
    const module = modules?.[index];
    if (!module)
      return false;
    const place = root._place(module.place.x, module.place.y, w, h);
    return w <= GridPlacement.maxSpan && h <= GridPlacement.maxSpan && root._clear(modules, place, index);
  }

  // --- Editing ---

  // Runs an edit. `edit` returns the module to select, false for no
  // change, or undefined to keep the selection on its module. Then
  // shifts the grid so nothing sits at a negative place, or past 0, 0.
  function _edit(edit) {
    const modules = root._modules();
    if (!modules)
      return;
    const before = modules[root.selected] ?? null;
    const was = JSON.parse(JSON.stringify(modules));
    const focus = edit(modules);
    if (focus === false)
      return;
    root.shifted(GridPlacement.normalize(modules), was);
    const target = focus ?? before;
    root._selected = target ? modules.indexOf(target) : -1;
    root.edited();
  }

  function _newModule(type, place) {
    const module = ConfigManager.withDefaults({
      "type": type
    }, "OverlayModule");
    module.place = place;
    return module;
  }

  // A new module at its schema defaults: at `place` when given (refused if
  // it doesn't fit or isn't clear), else at its default size in the first
  // free spot
  function addModule(type, place) {
    root._edit(modules => {
      let at = place;
      if (!at) {
        const size = OverlayConfig.defaultSize(type);
        at = GridPlacement.firstFree(modules, size[0], size[1]);
      } else if (!root.canAdd(type, at)) {
        return false;
      }
      const module = root._newModule(type, Object.assign({}, at));
      modules.push(module);
      return module;
    });
  }

  function moveModule(index, x, y) {
    if (!root.canMove(index, x, y))
      return;
    root._edit(modules => {
      const module = modules[index];
      if (module.place.x === x && module.place.y === y)
        return false;
      const place = root._place(x, y, module.place.w, module.place.h);
      const other = root._sameSpot(modules, place, index);
      if (other >= 0)
        modules[other].place = root._place(module.place.x, module.place.y, module.place.w, module.place.h);
      module.place = place;
      return module;
    });
  }

  function resizeModule(index, w, h) {
    const module = root.module(index);
    if (!module || (module.place.w === w && module.place.h === h) || !root.canResize(index, w, h))
      return;
    root._edit(modules => {
      modules[index].place = root._place(module.place.x, module.place.y, w, h);
      return modules[index];
    });
  }

  // A copy at the same size in the first free spot
  function duplicateModule(index) {
    root._edit(modules => {
      const module = modules[index];
      if (!module)
        return false;
      const copy = Utils.clone(module);
      copy.place = GridPlacement.firstFree(modules, module.place.w, module.place.h);
      modules.push(copy);
      return copy;
    });
  }

  function removeModule(index) {
    root._edit(modules => {
      if (!modules[index])
        return false;
      // A removed selection isn't found again, so it clears
      modules.splice(index, 1);
    });
  }

  function updateModuleProperty(index, key, value) {
    const module = root.module(index);
    if (!module || JSON.stringify(module.properties?.[key]) === JSON.stringify(value))
      return;
    if (!module.properties)
      module.properties = {};
    module.properties[key] = value;
    root.edited();
  }
}
