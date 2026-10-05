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
 * the grid (negative x or y) makes room there. A grid with an `area` (the
 * lock screen's) is bounded instead: places are absolute, inside it.
 * Required module types (`x-required`) are never removed or duplicated. */
QtObject {
  id: root

  // Returns the modules array being edited (mutated in place), or null
  property var modulesOf: () => null
  // Where the modules are shown: "overlay", "edgeMenu" or "lockscreen"
  // (x-hosts)
  property string host: "overlay"
  // A bounded grid ({ cols, rows }): modules stay inside it where they
  // are put, and the grid never shifts. null: it grows and shifts back
  // to 0, 0 after every edit
  property var area: null
  // How many of this grid's units make one of a card's quarters (2 on a
  // doubled lock screen grid): new modules' default sizes scale by it
  property int sizeScale: 1
  // What's being edited (a page, a menu): forms are rebuilt when it changes
  property string scopeKey: ""

  // Called in every edit, as the grid shifts back to 0, 0: with the shift
  // taken off ({ x, y } grid units, a place left of or above the grid
  // being negative) and how far the modules reached before the edit
  // (GridPlacement.bounds), so an owner can keep them where they were
  property var shifted: (shift, boundsBefore) => {}

  // After every edit: the owner marks its draft changed
  signal edited

  // Index of the selected module, -1 for none
  readonly property int selected: root._selected
  property int _selected: -1

  // Why these modules can't be saved as is, each prefixed with `name`
  function problemsFor(modules, name) {
    const out = [];
    // I18n.tr("an overlay page") I18n.tr("an edge menu") I18n.tr("the lock screen") I18n.tr("the login screen")
    const hostName = I18n.tr(({
        "overlay": "an overlay page",
        "edgeMenu": "an edge menu",
        "lockscreen": "the lock screen",
        "greeter": "the login screen"
      })[root.host] ?? root.host);
    (modules ?? []).forEach((module, i) => {
      const type = module?.type;
      if (type && !OverlayConfig.allowedIn(type, root.host))
        out.push(I18n.tr("{0}: {1} can't be placed on {2}", name, type, hostName));
      if (!GridPlacement.canPlace(modules.slice(0, i), module?.place, -1))
        out.push(I18n.tr("{0}: {1} overlaps another module", name, type));
      else if (root.area && !GridPlacement.within(module.place, root.area.cols, root.area.rows))
        out.push(I18n.tr("{0}: {1} is outside the grid", name, type));
    });
    OverlayConfig.requiredFor(root.host).forEach(type => {
      if (!(modules ?? []).some(module => module?.type === type))
        out.push(I18n.tr("{0}: needs its {1} module", name, type));
    });
    return out;
  }

  // A new `type` module's [w, h] on this grid
  function defaultSize(type) {
    return OverlayConfig.defaultSize(type).map(n => Math.min(GridPlacement.maxSpan, n * root.sizeScale));
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

  // Whether `place` is clear of every module but the one at `ignore`:
  // inside the `area` when there is one, else negative x and y allowed
  // (the grid shifts to make room)
  function _clear(modules, place, ignore) {
    if (root.area && !GridPlacement.within(place, root.area.cols, root.area.rows))
      return false;
    return place.w >= 1 && place.h >= 1 && !(modules ?? []).some((module, i) => i !== ignore && module?.place && GridPlacement.overlaps(module.place, place));
  }

  // A free w × h spot: in the area, else null; else the grid's first
  // (GridPlacement.firstFree)
  function _freeSpot(modules, w, h) {
    return root.area ? GridPlacement.firstFreeIn(modules, w, h, root.area.cols, root.area.rows) : GridPlacement.firstFree(modules, w, h);
  }

  // Whether module `index` may be removed or duplicated (not a required
  // one)
  function canRemove(index) {
    const type = root.module(index)?.type;
    return !!type && !OverlayConfig.isRequired(type);
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
    return OverlayConfig.allowedIn(type, root.host) && !OverlayConfig.isRequired(type) && root._clear(root._modules(), place, -1);
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
  // shifts the grid so nothing sits at a negative place, or past 0, 0
  // (unless it's bounded by an `area`).
  function _edit(edit) {
    const modules = root._modules();
    if (!modules)
      return;
    const before = modules[root.selected] ?? null;
    const boundsBefore = GridPlacement.bounds(modules);
    const focus = edit(modules);
    if (focus === false)
      return;
    if (!root.area)
      root.shifted(GridPlacement.normalize(modules), boundsBefore);
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
  // free spot (refused when a bounded grid has none)
  function addModule(type, place) {
    root._edit(modules => {
      let at = place;
      if (!at) {
        const size = root.defaultSize(type);
        at = root._freeSpot(modules, size[0], size[1]);
        if (!at || !root.canAdd(type, at))
          return false;
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
    if (!root.canRemove(index))
      return;
    root._edit(modules => {
      const module = modules[index];
      const place = root._freeSpot(modules, module.place.w, module.place.h);
      if (!place)
        return false;
      const copy = Utils.clone(module);
      copy.place = place;
      modules.push(copy);
      return copy;
    });
  }

  function removeModule(index) {
    if (!root.canRemove(index))
      return;
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
