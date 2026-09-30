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
 */
QtObject {
  id: root

  readonly property string savedDir: Paths.configPath + "user/saved/"
  // Newest first; roles: fileBaseName, filePath, fileModified
  readonly property FolderListModel model: _model
  // Last save/restore/delete outcome, for the settings UI
  property string status: ""

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
    _writer.path = savedDir + fileName + ".json";
    _writer.setText(JSON.stringify(ConfigManager.config, null, 2) + "\n");
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
    SettingsManager.loadConfig();
    ThemeManager.applyWallpapers();
    root.status = I18n.tr("Restored the default configuration");
    console.log("[SavedConfigsManager] Restored defaults");
  }

  function remove(name) {
    _run(["rm", "-f", "--", savedDir + name + ".json"], I18n.tr("Deleted \"{0}\"", name), I18n.tr("Failed to delete \"{0}\"", name));
  }

  function _run(command, okText, failText) {
    if (_process.running) {
      root.status = I18n.tr("Busy, try again");
      return;
    }
    _process.okText = okText;
    _process.failText = failText;
    _process.command = command;
    _process.running = true;
  }

  property Process _process: Process {
    property string okText
    property string failText
    stderr: StdioCollector {
      onStreamFinished: {
        if (text.trim() !== "")
          console.error("[SavedConfigsManager]", text.trim());
      }
    }
    onExited: code => {
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
