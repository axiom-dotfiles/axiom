pragma Singleton
import QtQuick

import qs.config
import qs.components.methods

/* OverlayManager holds the overlay editor's working copy of Overlay.views
 * (the editor is the pinned last page). Edits only affect localViews and
 * the editor's canvas; the real overlay pages and config.json are
 * untouched until saveChanges(). Mirrors BarManager.
 *
 * Also keeps the page's own state (selected page), since the page is
 * unloaded whenever the overlay closes. The selected page's columns are
 * edited through `layout` (ColumnsEditor, which also holds the selected
 * slot). */
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

  property ColumnsEditor layout: ColumnsEditor {
    host: "overlay"
    columnsOf: () => root.selectedView()?.columns ?? null
    scopeKey: String(root.selectedViewIndex)
    onEdited: root.applyChanges()
  }

  // Why the draft can't be saved as is (empty = savable)
  readonly property var problems: {
    const out = [];
    (root.localViews ?? []).forEach((view, v) => {
      if (view.type === "Custom")
        out.push(...root.layout.problemsFor(view.columns, view.name || I18n.tr("Page {0}", v + 1)));
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

  function _defaults(value, definition) {
    return SchemaValidation.applyDefaults(value, {
      "$ref": "#/definitions/" + definition
    }, ConfigManager.configSchema);
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
    root.layout.clearSelection();
  }

  function addView(type) {
    const view = type === "Custom" ? {
      "type": "Custom",
      "name": I18n.tr("Page {0}", root.localViews.length + 1),
      "columns": [
        {
          "cells": [root.layout.newCell()]
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
    if (root.layout.moveTo(root.localViews, from, to) < 0)
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
