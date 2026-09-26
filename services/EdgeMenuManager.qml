pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

import qs.config
import qs.components.methods

// Which edge menus (EdgeMenusConfig) are open and which are pinned. The
// menus themselves (shell/EdgeMenus) follow this and report back when they
// close on their own. Kept across QML reloads, so a reload doesn't close an
// integrated menu and reflow the windows.
//
// Also the edge menu editor's working copy of EdgeMenus (the pinned
// EdgeMenuEditor overlay page), as BarManager is the bar editor's: edits
// show live on the running menus (ConfigManager.previews) until saved or
// reset, and `previewing` holds one menu open to try them on.
//
//   qs -c axiom ipc call edgeMenu toggle <id>
Singleton {
  id: root

  // { id: true } for each open / pinned menu
  readonly property var openMenus: root._parse(_run.open)
  readonly property var pinnedMenus: root._parse(_run.pinned)

  // What opened each menu (a bar button), which keeps a floating menu open
  // while hovered, as a bar popout's anchor does. Not kept across reloads.
  property var anchors: ({})

  // Space open integrated menus reserve, by "<screen>:<edge>" (edge
  // "top" | "bottom" | "left" | "right"), for surfaces that place
  // themselves against the perpendicular edges (BarPopouts)
  property var zones: ({})

  function setZone(screenName, edge, size) {
    const key = `${screenName}:${edge}`;
    if ((root.zones[key] ?? 0) === size)
      return;
    const zones = Object.assign({}, root.zones);
    if (size > 0)
      zones[key] = size;
    else
      delete zones[key];
    root.zones = zones;
  }

  function zoneOn(screenName, edge) {
    return root.zones[`${screenName}:${edge}`] ?? 0;
  }

  PersistentProperties {
    id: _run
    reloadableId: "axiomEdgeMenus"
    // JSON lists of ids
    property string open: "[]"
    property string pinned: "[]"
  }

  function _parse(json) {
    try {
      return JSON.parse(json).reduce((map, id) => {
        map[id] = true;
        return map;
      }, {});
    } catch (e) {
      return {};
    }
  }

  function _set(map, id, on) {
    const ids = Object.keys(map).filter(key => key !== id);
    if (on)
      ids.push(id);
    return JSON.stringify(ids);
  }

  // True for a menu held open by the editor: it ignores closeOnLeave and
  // outside clicks, as a pinned one does
  function isHeld(id) {
    return root.isPinned(id) || (id !== "" && root.previewing === id);
  }

  function isOpen(id) {
    return root.openMenus[id] === true;
  }
  function isPinned(id) {
    return root.pinnedMenus[id] === true;
  }

  function open(id, anchor) {
    if (!EdgeMenusConfig.menuById(id)) {
      console.warn("No edge menu with id", id);
      return;
    }
    const anchors = Object.assign({}, root.anchors);
    anchors[id] = anchor ?? null;
    root.anchors = anchors;
    _run.open = root._set(root.openMenus, id, true);
  }

  function close(id) {
    if (!root.isOpen(id))
      return;
    _run.open = root._set(root.openMenus, id, false);
  }

  function toggle(id, anchor) {
    if (root.isOpen(id))
      root.close(id);
    else
      root.open(id, anchor);
  }

  function setPinned(id, pinned) {
    _run.pinned = root._set(root.pinnedMenus, id, pinned);
  }

  function togglePinned(id) {
    root.setPinned(id, !root.isPinned(id));
  }

  // --- Editor ---

  property ConfigDraft _draft: ConfigDraft {
    id: draft
    path: ["EdgeMenus"]
  }
  readonly property alias localMenus: draft.local
  readonly property alias savedMenus: draft.saved
  readonly property alias isDirty: draft.isDirty
  property int selectedMenuIndex: 0

  // The selected menu's columns (see ColumnsEditor)
  property ColumnsEditor layout: ColumnsEditor {
    host: "edgeMenu"
    columnsOf: () => root.selectedMenu()?.columns ?? null
    scopeKey: String(root.selectedMenuIndex)
    onEdited: root.applyChanges()
  }

  // The menu the editor holds open to try edits on ("" for none)
  property string previewing: ""

  // Why the draft can't be saved as is (empty = savable)
  readonly property var problems: {
    const out = [];
    const menus = root.localMenus ?? [];
    menus.forEach((menu, m) => {
      const name = root.menuLabel(menu, m);
      if (!menu.id)
        out.push(I18n.tr("{0} has no id", name));
      else if (menus.findIndex(other => other.id === menu.id) !== m)
        out.push(I18n.tr("{0}: another menu has the id {1}", name, menu.id));
      out.push(...root.layout.problemsFor(menu.columns, name));
    });
    return out;
  }

  function menuLabel(menu, index) {
    return menu?.name || menu?.id || I18n.tr("Menu {0}", index + 1);
  }

  // Keeps the selected menu where it still exists
  function loadConfig() {
    draft.load();
    ConfigManager.clearPreview("EdgeMenus");
    root.selectedMenuIndex = Math.max(0, Math.min(root.selectedMenuIndex, (root.localMenus?.length ?? 1) - 1));
    root.layout.clearSelection();
    root._followPreview();
  }

  // Loads the draft unless it holds unsaved edits (the page is rebuilt
  // whenever the overlay reopens)
  function ensureLoaded() {
    if (!draft.isDirty)
      root.loadConfig();
  }

  // Call after mutating localMenus in place: shows the edit on the running
  // menus while the draft differs from the saved config
  function applyChanges() {
    draft.changed();
    if (draft.isDirty)
      ConfigManager.setPreview("EdgeMenus", draft.local);
    else
      ConfigManager.clearPreview("EdgeMenus");
  }

  // Whether a menu differs from its saved version (matched by id)
  function menuChanged(index) {
    const menu = root.localMenus?.[index];
    const saved = (root.savedMenus ?? []).find(m => m.id === menu?.id);
    return JSON.stringify(menu) !== JSON.stringify(saved);
  }

  function selectedMenu() {
    return root.localMenus?.[root.selectedMenuIndex] || null;
  }

  function selectMenu(index) {
    if (index === root.selectedMenuIndex)
      return;
    root.selectedMenuIndex = index;
    root.layout.clearSelection();
    root._followPreview();
  }

  function _uniqueId(base) {
    const taken = (root.localMenus ?? []).map(menu => menu.id);
    let n = 1;
    while (taken.includes(`${base}-${n}`))
      n++;
    return `${base}-${n}`;
  }

  // A new menu at the schema defaults, with one empty cell to drop into
  function addMenu() {
    const menu = SchemaValidation.applyDefaults({
      "id": root._uniqueId("menu"),
      "columns": [
        {
          "cells": [root.layout.newCell()]
        }
      ]
    }, {
      "$ref": "#/definitions/EdgeMenu"
    }, ConfigManager.configSchema);
    root.localMenus.push(menu);
    root.applyChanges();
    root.selectMenu(root.localMenus.length - 1);
  }

  function duplicateMenu(index) {
    const menu = root.localMenus?.[index];
    if (!menu)
      return;
    const copy = JSON.parse(JSON.stringify(menu));
    copy.id = root._uniqueId(menu.id || "menu");
    if (copy.name)
      copy.name = I18n.tr("{0} (copy)", copy.name);
    root.localMenus.splice(index + 1, 0, copy);
    root.applyChanges();
    root.selectMenu(index + 1);
  }

  function removeMenu(index) {
    const menu = root.localMenus?.[index];
    if (!menu)
      return;
    if (root.previewing === menu.id)
      root._showPreview("");
    root.localMenus.splice(index, 1);
    root.selectedMenuIndex = Math.max(0, Math.min(root.selectedMenuIndex, root.localMenus.length - 1));
    root.layout.clearSelection();
    root.applyChanges();
    root._followPreview();
  }

  // One of the selected menu's own fields (not its columns)
  function updateMenuField(key, value) {
    const menu = root.selectedMenu();
    if (!menu || JSON.stringify(menu[key]) === JSON.stringify(value))
      return;
    const wasPreviewing = root.previewing !== "" && root.previewing === menu.id;
    if (wasPreviewing && key === "id")
      root._showPreview("");
    menu[key] = value;
    root.applyChanges();
    // A renamed (or re-enabled) menu is a new window: open that one
    if (wasPreviewing || (root._wantPreview && key === "enabled"))
      Qt.callLater(root._followPreview);
  }

  // --- Trying a menu out ---

  // Whether the editor wants the selected menu held open; stays set while
  // switching menus, so the preview follows the selection
  property bool _wantPreview: false

  function canPreview(menu) {
    return !!menu?.id && menu.enabled !== false;
  }

  function startPreviewing() {
    root._wantPreview = true;
    root._followPreview();
  }

  function stopPreviewing() {
    root._wantPreview = false;
    root._showPreview("");
  }

  function togglePreviewing() {
    if (root._wantPreview)
      root.stopPreviewing();
    else
      root.startPreviewing();
  }

  function _followPreview() {
    if (!root._wantPreview)
      return;
    const menu = root.selectedMenu();
    root._showPreview(root.canPreview(menu) ? menu.id : "");
  }

  function _showPreview(id) {
    if (root.previewing === id)
      return;
    if (root.previewing !== "")
      root.close(root.previewing);
    root.previewing = id;
    // After the preview reaches EdgeMenusConfig, so a new menu exists
    if (id !== "")
      Qt.callLater(() => {
        if (root.previewing === id)
          root.open(id, null);
      });
  }

  function saveChanges() {
    if (root.problems.length > 0)
      return false;
    if (!draft.save())
      return false;
    ConfigManager.clearPreview("EdgeMenus");
    return true;
  }

  function resetChanges() {
    root.loadConfig();
  }

  property IpcHandler _ipc: IpcHandler {
    target: "edgeMenu"

    function open(id: string): void {
      root.open(id, null);
    }

    function close(id: string): void {
      root.close(id);
    }

    function toggle(id: string): void {
      root.toggle(id, null);
    }

    function pin(id: string): void {
      root.setPinned(id, true);
    }

    function unpin(id: string): void {
      root.setPinned(id, false);
    }

    // Opens the edge menu editor
    function edit(): void {
      ShellManager.openOverlayPage("EdgeMenuEditor");
    }

    function list(): string {
      return EdgeMenusConfig.menus.map(menu => `${menu.id}${root.isOpen(menu.id) ? " (open)" : ""}${root.isPinned(menu.id) ? " (pinned)" : ""}`).join("\n");
    }
  }
}
