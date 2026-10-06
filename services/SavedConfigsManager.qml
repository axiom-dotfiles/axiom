pragma Singleton
import QtQuick
import Qt.labs.folderlistmodel
import Quickshell.Io

import qs.config
import qs.components.methods

/**
 * Named snapshots of the whole config, one JSON file each in
 * config/user/saved/. A saved file is a plain config.json, so it can also
 * be copied into place by hand. Restoring runs it through ConfigManager's
 * load pipeline, so snapshots from older config versions are migrated.
 * The one last saved or restored is `active`, and `modified` says whether
 * the running config has changed since.
 */
QtObject {
  id: root

  readonly property string savedDir: Paths.configPath + "user/saved/"
  // Newest first; roles: fileBaseName, filePath, fileModified
  readonly property FolderListModel model: _model
  // Last save/restore/delete outcome, for the settings UI
  property string status: ""
  // The saved config the running one was last saved as or restored from,
  // "" for none (or once its file is gone): the one the settings UI offers
  // to overwrite. Kept in state/savedconfigs.json.
  readonly property string active: _model.count > 0 && exists(_active) ? _active : ""
  // Whether the running config differs from the active saved one
  readonly property bool modified: active !== "" && _baseline !== null && !Utils.deepEqual(ConfigManager.config, _baseline)

  property string _active: ""
  // The active saved config as it loads (migrated, defaults filled)
  property var _baseline: null
  // The config being written by save(), the new baseline once it's saved
  property var _saving: null
  readonly property var _state: StateManager.createStateHandler("savedconfigs")

  Component.onCompleted: {
    root._active = root._state.load({}).active ?? "";
    root._loadBaseline();
  }

  function sanitize(name) {
    return name.trim().replace(/[^A-Za-z0-9 _.-]/g, "_").replace(/^\.+/, "");
  }

  function exists(name) {
    const fileName = sanitize(name) + ".json";
    for (let i = 0; i < _model.count; i++) {
      if (_model.get(i, "fileName") === fileName)
        return true;
    }
    return false;
  }

  // Saves the running config (including unsaved settings edits) under `name`,
  // replacing any existing snapshot of that name.
  function save(name) {
    const fileName = sanitize(name);
    if (fileName === "") {
      root.status = I18n.tr("Enter a name to save as");
      return;
    }
    // Written by a FileView, not through argv, which caps one argument at
    // 128 KiB (the folder was made at startup)
    _writer.name = fileName;
    root._saving = Utils.clone(ConfigManager.config);
    _writer.path = savedDir + fileName + ".json";
    _writer.setText(JSON.stringify(root._saving, null, 2) + "\n");
  }

  function restore(name) {
    const path = savedDir + name + ".json";
    const content = FileManager.read("file://" + path);
    // JSON.parse(null) is null, which would restore pure defaults
    if (!content) {
      console.error("[SavedConfigsManager] Could not read", path);
      root.status = I18n.tr("\"{0}\" could not be read", name);
      return;
    }
    let parsed;
    try {
      parsed = JSON.parse(content);
    } catch (e) {
      console.error("[SavedConfigsManager] Could not parse", path, e);
      root.status = I18n.tr("\"{0}\" is not valid JSON", name);
      return;
    }
    if (!ConfigManager.restoreConfig(parsed)) {
      root.status = I18n.tr("\"{0}\" is not a valid config", name);
      return;
    }
    root._setActive(name, ConfigManager.config);
    SettingsManager.loadConfig();
    ThemeManager.applyWallpapers();
    root.status = I18n.tr("Restored \"{0}\"", name);
    console.log("[SavedConfigsManager] Restored", path);
  }

  // Replaces the config with the schema defaults (what a first run writes).
  // The current version skips migration, which would otherwise treat the
  // empty object as a version 1 config.
  function restoreDefaults() {
    if (!ConfigManager.restoreConfig({
      "version": ConfigMigration.currentVersion
    })) {
      root.status = I18n.tr("The default configuration is not valid");
      return;
    }
    root._setActive("", null);
    SettingsManager.loadConfig();
    ThemeManager.applyWallpapers();
    root.status = I18n.tr("Restored the default configuration");
    console.log("[SavedConfigsManager] Restored defaults");
  }

  function remove(name) {
    _run(["rm", "-f", "--", savedDir + name + ".json"], I18n.tr("Deleted \"{0}\"", name), I18n.tr("Failed to delete \"{0}\"", name), name);
  }

  // `baseline`: the config as saved, or undefined to read it from the file
  function _setActive(name, baseline) {
    root._active = name;
    root._state.save({
      "active": name
    });
    if (baseline === undefined)
      root._loadBaseline();
    else
      root._baseline = baseline === null ? null : Utils.clone(baseline);
  }

  function _loadBaseline() {
    root._baseline = null;
    if (root._active === "")
      return;
    const content = FileManager.read("file://" + savedDir + root._active + ".json");
    if (!content)
      return;
    try {
      root._baseline = ConfigManager.normalizeConfig(JSON.parse(content));
    } catch (e) {
      console.warn("[SavedConfigsManager] Could not parse the active saved config", root._active + ":", e);
    }
  }

  // `removed`: the saved config the command deletes, if any
  function _run(command, okText, failText, removed = "") {
    if (_process.running) {
      root.status = I18n.tr("Busy, try again");
      return;
    }
    _process.okText = okText;
    _process.failText = failText;
    _process.removed = removed;
    _process.command = command;
    _process.running = true;
  }

  property Process _process: Process {
    property string okText
    property string failText
    property string removed
    stderr: StdioCollector {
      onStreamFinished: {
        if (text.trim() !== "")
          console.error("[SavedConfigsManager]", text.trim());
      }
    }
    onExited: code => {
      if (code === 0 && removed !== "" && removed === root._active)
        root._setActive("", null);
      root.status = code === 0 ? okText : failText;
      console.log("[SavedConfigsManager]", root.status);
    }
  }

  property FileView _writer: FileView {
    property string name
    blockWrites: true
    atomicWrites: true
    printErrors: false
    onSaved: {
      root._setActive(name, root._saving);
      root.status = I18n.tr("Saved \"{0}\"", name);
      console.log("[SavedConfigsManager]", root.status);
    }
    onSaveFailed: error => {
      root.status = I18n.tr("Failed to save \"{0}\"", name);
      console.warn("[SavedConfigsManager] Could not write", path + ":", FileViewError.toString(error));
    }
  }

  // The folder must exist before FolderListModel watches it, or it never
  // picks up files saved later.
  property Process _mkdir: Process {
    running: true
    command: ["mkdir", "-p", root.savedDir]
    onExited: root._model.folder = "file://" + root.savedDir
  }

  property FolderListModel _model: FolderListModel {
    nameFilters: ["*.json"]
    showDirs: false
    sortField: FolderListModel.Time
  }
}
