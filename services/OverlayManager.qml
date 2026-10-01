pragma Singleton
import QtQuick

import qs.config
import qs.components.methods

/* OverlayManager holds the layouts editor's working copy of Overlay.views
 * (the editor is the pinned last page). Edits only affect localViews and
 * the editor's canvas; the real overlay pages and config.json are
 * untouched until saveChanges(). Mirrors BarManager.
 *
 * Also keeps the page's own state, since the page is unloaded whenever the
 * overlay closes: whether it's editing a page or an edge menu
 * (`editTarget`; the menus themselves are EdgeMenuManager's), the selected
 * page, and each overlay's room (for the canvas's "fits" line). The
 * selected page's modules are edited through `layout` (GridEditor, which
 * also holds the selected module). */
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
  // What the layouts editor shows: "page" (selectedViewIndex) or "menu"
  // (EdgeMenuManager.selectedMenuIndex)
  property string editTarget: "page"

  property GridEditor layout: GridEditor {
    host: "overlay"
    modulesOf: () => root.selectedView()?.type === "Custom" ? root.selectedView().modules : null
    scopeKey: String(root.selectedViewIndex)
    onEdited: root.applyChanges()
  }

  // Why the draft can't be saved as is (empty = savable)
  readonly property var problems: {
    const out = [];
    (root.localViews ?? []).forEach((view, v) => {
      if (view.type === "Custom")
        out.push(...root.layout.problemsFor(view.modules, OverlayConfig.viewLabel(view, v)));
    });
    return out;
  }

  // Keeps the selected page where it still exists
  function loadConfig() {
    draft.load();
    root.selectedViewIndex = Math.max(0, Math.min(root.selectedViewIndex, (root.localViews?.length ?? 1) - 1));
    root.layout.clearSelection();
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

  // Whether a page differs from the saved page at the same position
  function viewChanged(index) {
    return JSON.stringify(root.localViews?.[index]) !== JSON.stringify(root.savedViews?.[index]);
  }

  // --- What the editor shows ---

  function editPage(index) {
    root.editTarget = "page";
    root.selectView(index);
  }

  function editMenu(index) {
    root.editTarget = "menu";
    EdgeMenuManager.selectMenu(index);
  }

  // The pages, or the menus, keeping what was selected in each
  function editPages() {
    root.editTarget = "page";
  }

  function editMenus() {
    root.editTarget = "menu";
  }

  // --- Room on each screen ---

  // { screenName: { width, height, unit } }: the room each overlay has for
  // a page, and its card size, as its OverlayPanel reports them
  property var areas: ({})

  function reportArea(screenName, width, height, unit) {
    const old = root.areas[screenName];
    if (old && old.width === width && old.height === height && old.unit === unit)
      return;
    const areas = Object.assign({}, root.areas);
    areas[screenName] = {
      "width": width,
      "height": height,
      "unit": unit
    };
    root.areas = areas;
  }

  // A screen's overlay is gone (its screen was unplugged)
  function clearArea(screenName) {
    if (!(screenName in root.areas))
      return;
    const areas = Object.assign({}, root.areas);
    delete areas[screenName];
    root.areas = areas;
  }

  // How much each screen's overlay shrinks a page of these modules:
  // [{ screen, scale }], 1 where it fits
  function fitOf(modules) {
    const bounds = GridPlacement.bounds(modules);
    return Object.keys(root.areas).sort().map(screenName => {
      const area = root.areas[screenName];
      return {
        "screen": screenName,
        "scale": GridPlacement.fitScale(bounds, area.width, area.height, area.unit)
      };
    });
  }

  // --- Pages ---

  function selectedView() {
    return root.localViews?.[root.selectedViewIndex] || null;
  }

  function selectView(index) {
    root.selectedViewIndex = index;
    root.layout.clearSelection();
  }

  // A new Custom page, selected (tool pages are always in config: they're
  // hidden, never added or removed)
  function addView() {
    const taken = root.localViews.map(v => v.name);
    let n = 1;
    while (taken.includes(I18n.tr("Page {0}", n)))
      n++;
    root.localViews.push(ConfigManager.withDefaults({
      "type": "Custom",
      "name": I18n.tr("Page {0}", n),
      "modules": []
    }, "OverlayView"));
    root.editPage(root.localViews.length - 1);
    applyChanges();
  }

  // Inserts a copy of a Custom page after it and selects it
  function duplicateView(index) {
    const view = root.localViews?.[index];
    if (view?.type !== "Custom")
      return;
    const copy = Utils.clone(view);
    copy.name = I18n.tr("{0} (copy)", OverlayConfig.viewLabel(view, index));
    root.localViews.splice(index + 1, 0, copy);
    root.editPage(index + 1);
    applyChanges();
  }

  function removeView(index) {
    if (root.localViews?.[index]?.type !== "Custom")
      return;
    // The selected page stays selected unless it's the one removed
    const selectedView = root.selectedView();
    root.localViews.splice(index, 1);
    const kept = root.localViews.indexOf(selectedView);
    if (kept >= 0)
      root.selectedViewIndex = kept;
    else
      root.selectView(Math.max(0, Math.min(root.selectedViewIndex, root.localViews.length - 1)));
    applyChanges();
  }

  // The selected page stays selected wherever it ends up
  function moveView(from, to) {
    const selectedView = root.selectedView();
    if (GridPlacement.moveTo(root.localViews, from, to) < 0)
      return;
    root.selectedViewIndex = Math.max(0, root.localViews.indexOf(selectedView));
    applyChanges();
  }

  // One of a page's own fields (name, icon, visible)
  function updateViewField(index, key, value) {
    const view = root.localViews?.[index];
    if (!view || JSON.stringify(view[key]) === JSON.stringify(value))
      return;
    view[key] = value;
    applyChanges();
  }

  function renameView(index, name) {
    root.updateViewField(index, "name", name);
  }

  // Shown in the navigator (true) or hidden; hidden pages keep their place
  function setViewVisible(index, visible) {
    const view = root.localViews?.[index];
    if (!view || (view.visible !== false) === visible)
      return;
    if (visible)
      delete view.visible;
    else
      view.visible = false;
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
