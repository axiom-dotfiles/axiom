pragma Singleton
import QtQuick
import Quickshell

import qs.config
import qs.components.methods

/* The settings page's working copy of the config. Edits are applied live
 * (in memory) as they're made; saveChanges() persists them, resetChanges()
 * reloads from disk. Only the settings actually edited are applied and
 * saved, onto the latest config, so changes made elsewhere meanwhile (a
 * theme, a wallpaper, the bar editor) survive.
 *
 * Also keeps the page's own state (category, search), since the page is
 * unloaded whenever the overlay closes. */
QtObject {
  id: root

  property ConfigDraft _draft: ConfigDraft {
    id: draft
  }
  readonly property alias localConfig: draft.local
  readonly property alias savedConfig: draft.saved
  readonly property alias isDirty: draft.isDirty

  // Key paths ("Appearance.font.size") that differ from the saved config;
  // arrays count as one value
  readonly property var changedPaths: _diff(draft.local, draft.saved, [])
  readonly property int changedCount: changedPaths.length

  // The settings page's selected category and search text
  property string category: ""
  property string query: ""

  function _diff(local, saved, path) {
    const isObject = value => value !== null && typeof value === "object" && !Array.isArray(value);
    if (isObject(local) && isObject(saved)) {
      const keys = Object.keys(local).concat(Object.keys(saved).filter(key => !(key in local)));
      return [].concat(...keys.map(key => _diff(local[key], saved[key], path.concat(key))));
    }
    return JSON.stringify(local) === JSON.stringify(saved) ? [] : [path.join(".")];
  }

  function isChanged(path) {
    return root.changedPaths.includes(path.join("."));
  }

  // Whether anything under a path prefix (e.g. a section key) has changed
  function hasChangesUnder(prefix) {
    return root.changedPaths.some(changed => changed === prefix || changed.startsWith(prefix + "."));
  }

  function loadConfig() {
    draft.load();
  }

  // Loads the draft unless it holds unsaved edits (the page is rebuilt
  // whenever the overlay reopens)
  function ensureLoaded() {
    if (!draft.isDirty)
      draft.load();
  }

  function markDirty() {
    draft.changed();
  }

  function _clone(value) {
    return JSON.parse(JSON.stringify(value ?? null));
  }

  function _valueAt(object, path) {
    let cur = object;
    for (const key of path)
      cur = cur?.[key];
    return cur;
  }

  function _setAt(object, path, value) {
    let cur = object;
    for (let i = 0; i < path.length - 1; i++) {
      if (typeof cur[path[i]] !== "object" || cur[path[i]] === null)
        cur[path[i]] = {};
      cur = cur[path[i]];
    }
    cur[path[path.length - 1]] = _clone(value);
  }

  // The latest config with every changed setting from the draft on top
  function _merged() {
    const merged = _clone(ConfigManager.config);
    for (const changed of root.changedPaths) {
      const path = changed.split(".");
      _setAt(merged, path, _valueAt(draft.local, path));
    }
    return merged;
  }

  // Sets one value by path (e.g. ["Appearance", "shape", "radius"]) and
  // applies it live.
  function setValue(path, value) {
    _setAt(draft.local, path, value);
    // `x-applyOnSave` settings (Hyprland's mode, which can take over files)
    // wait in the draft until Save
    if (!schemaAt(path)?.["x-applyOnSave"]) {
      const live = _clone(ConfigManager.config);
      _setAt(live, path, value);
      ConfigManager.applyConfig(live);
    }
    draft.changed();
  }

  // The schema of the setting at a key path
  function schemaAt(path) {
    let node = ConfigManager.configSchema;
    for (const key of path)
      node = node?.properties?.[key];
    return node;
  }

  // The choices for a string setting (`enum` or `x-options`), else null
  function optionsFor(fieldSchema) {
    if (fieldSchema?.enum)
      return fieldSchema.enum;
    switch (fieldSchema?.["x-options"]) {
    case "screens":
      return ["", ...Quickshell.screens.map(screen => screen.name)];
    case "chatBackends":
      return Object.keys(ConfigManager.config.Chat.backends);
    case "colors":
      return Theme.baseColorNames;
    case "languages":
      return I18n.languages.map(l => l.code);
    }
    return null;
  }

  // --- Setting single values from outside the page (the launcher's /config) ---

  // Never offered, whatever the schema says: the bar and overlay editors
  // own these
  readonly property var _blockedPrefixes: ["Bars", "Overlay.views"]

  // Every value the settings page shows, as { path, key, schema }, with
  // key the dotted path. `x-applyOnSave` settings are left out: they wait
  // for the page's Save for a reason (Hyprland's mode can take over files).
  readonly property var settingPaths: {
    const schema = ConfigManager.configSchema;
    if (!schema?.properties)
      return [];
    return SchemaLayout.rows(schema, []).filter(row => row.kind === "field" && !row.schema["x-applyOnSave"]).map(row => ({
          path: row.path,
          key: row.path.join("."),
          schema: row.schema
        })).filter(entry => !root._blockedPrefixes.some(prefix => entry.key === prefix || entry.key.startsWith(prefix + ".")));
  }

  function settingFor(key) {
    const wanted = key.toLowerCase();
    return root.settingPaths.find(entry => entry.key.toLowerCase() === wanted) ?? null;
  }

  // Parses typed text for a setting: { value } or { error }
  function parseValue(schema, text) {
    const trimmed = text.trim();
    switch (schema.type) {
    case "boolean":
      {
        const word = trimmed.toLowerCase();
        if (["on", "true", "yes", "1"].includes(word))
          return {
            value: true
          };
        if (["off", "false", "no", "0"].includes(word))
          return {
            value: false
          };
        return {
          error: I18n.tr("Must be on or off")
        };
      }
    case "integer":
      {
        if (!/^-?\d+$/.test(trimmed))
          return {
            error: I18n.tr("Must be a whole number")
          };
        const number = parseInt(trimmed);
        if (schema.minimum !== undefined && number < schema.minimum)
          return {
            error: I18n.tr("Must be at least {0}", schema.minimum)
          };
        if (schema.maximum !== undefined && number > schema.maximum)
          return {
            error: I18n.tr("Must be at most {0}", schema.maximum)
          };
        return {
          value: number
        };
      }
    case "array":
      {
        const items = trimmed === "" ? [] : trimmed.split(",").map(item => item.trim()).filter(item => item !== "");
        const allowed = schema.items?.enum;
        const bad = allowed ? items.find(item => !allowed.includes(item)) : undefined;
        if (bad !== undefined)
          return {
            error: I18n.tr("\"{0}\" is not one of {1}", bad, allowed.join(", "))
          };
        return {
          value: items
        };
      }
    default:
      {
        const value = trimmed === "\"\"" ? "" : trimmed;
        if (schema.enum && !schema.enum.includes(value))
          return {
            error: I18n.tr("Must be one of {0}", schema.enum.join(", "))
          };
        return {
          value: value
        };
      }
    }
  }

  // Sets one setting and saves it straight away, leaving any unsaved edits
  // on the page alone. False if it's not a setting offered here, or the
  // save is rejected.
  function commitValue(key, value) {
    const entry = settingFor(key);
    if (!entry)
      return false;
    const next = _clone(ConfigManager.config);
    _setAt(next, entry.path, value);
    if (!ConfigManager.commit(next))
      return false;
    ensureLoaded();
    return true;
  }

  // A value anywhere in the running config, by dotted path
  // ("Workspaces.layout"): what an `x-showIf` key starting with `/` reads
  function configValueAt(dottedPath) {
    return _valueAt(ConfigManager.config, dottedPath.split("."));
  }

  function valueOf(key) {
    const entry = settingFor(key);
    return entry ? _valueAt(ConfigManager.config, entry.path) : undefined;
  }

  // Stays dirty if the save is rejected (invalid, or saves are blocked)
  function saveChanges() {
    if (!ConfigManager.commit(_merged()))
      return false;
    draft.load();
    return true;
  }

  function resetChanges() {
    ConfigManager.hardResetConfig();
    draft.load();
  }
}
