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
 *
 * Also shares configs (ConfigExamples, by the schema's x-scope): applies
 * the example setups shipped in examples/ and imported files (the running
 * config is first saved as "before-<name>", then the file's look and layout
 * replace the running ones), and exports the running config's look to the
 * home folder in the same format. Nothing loaded changes a takeover setting
 * (the schema's x-takeover: the Hyprland mode, lock screen, idle, polkit,
 * greeter; ConfigManager.restoreConfig keeps them).
 */
QtObject {
  id: root

  readonly property string savedDir: Paths.configPath + "user/saved/"
  readonly property string examplesDir: Paths.axiomPath + "examples/"
  // [{ name, title, description }] by name, from examples/*.json
  readonly property var examples: {
    const list = [];
    for (let i = 0; i < _examplesModel.count; i++) {
      const name = _examplesModel.get(i, "fileBaseName");
      const example = _readExample(name);
      list.push({
        name: name,
        title: example?._example?.title ?? name,
        description: example?._example?.description ?? ""
      });
    }
    return list;
  }
  // Newest first; roles: fileBaseName, filePath, fileModified
  readonly property FolderListModel model: _model
  // Last save/restore/delete outcome, for the settings UI
  property string status: ""
  // The saved config the running one was last saved as or restored from,
  // "" for none (or once its file is gone): the one the settings UI offers
  // to overwrite. Kept in state/savedconfigs.json.
  readonly property string active: _model.count > 0 && exists(_active) ? _active : ""
  // Whether the running config differs from the active saved one, leaving
  // out the takeover settings, which restoring doesn't change
  readonly property bool modified: active !== "" && _baseline !== null && !Utils.deepEqual(ConfigManager.config, ConfigExamples.keepTakeovers(_baseline, ConfigManager.config, ConfigManager.configSchema))

  property string _active: ""
  // The active saved config as it loads (migrated, defaults filled)
  property var _baseline: null
  // The config being written by save(), the new baseline once it's saved
  // (dropped once it's written or fails)
  property var _saving: null
  // An imported file awaiting confirmation: { name, title, description,
  // path, config, hasPersonal } (config loaded: migrated, defaults filled;
  // hasPersonal: the file holds keybinds, apps or commands), or null
  property var importing: null
  // The file picker is open
  readonly property bool picking: _picker.running

  // What to apply once the running config is saved as its backup:
  // { name, config, personal }, or null
  property var _pendingApply: null
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

  // Saves the running config as "before-<name>", then applies the example
  // (in _writer's onSaved, so a failed backup applies nothing)
  function applyExample(name) {
    const example = _readExample(name);
    if (!example) {
      root.status = I18n.tr("\"{0}\" could not be read", name);
      return;
    }
    _backupThenApply(name, ConfigManager.normalizeConfig(example), false);
  }

  // Opens the desktop's file picker; the chosen file goes to openImport
  function browseImport() {
    if (_picker.running)
      return;
    _picker.command = ["python3", Paths.scriptsPath + "pick_file.py", I18n.tr("Import a configuration"), Paths.homeDirectory];
    // The picker is an ordinary window, under the overlay's layer
    ShellManager.beginStepAside("filePicker");
    _picker.running = true;
  }

  // Loads a shared file (an export, an example, or a whole config.json of
  // any version) as `importing`, for the settings page to confirm
  function openImport(path) {
    root.importing = null;
    const content = FileManager.read("file://" + path);
    const fileName = path.split("/").pop();
    if (!content) {
      root.status = I18n.tr("\"{0}\" could not be read", fileName);
      return;
    }
    let parsed;
    try {
      parsed = JSON.parse(content);
    } catch (e) {
      console.warn("[SavedConfigsManager] Could not parse", path + ":", e);
      root.status = I18n.tr("\"{0}\" is not valid JSON", fileName);
      return;
    }
    if (typeof parsed !== "object" || parsed === null || Array.isArray(parsed)) {
      root.status = I18n.tr("\"{0}\" is not a valid config", fileName);
      return;
    }
    // Without one it would be migrated as a version 1 config, which can
    // quietly rewrite a newer layout; a newer one would lose what this
    // version doesn't know
    const version = parsed.version;
    if (!Number.isInteger(version) || version < 1) {
      root.status = I18n.tr("\"{0}\" has no config version, so it can't be imported", fileName);
      return;
    }
    if (version > ConfigMigration.currentVersion) {
      root.status = I18n.tr("\"{0}\" is from a newer axiom. Update axiom to import it.", fileName);
      return;
    }
    const config = ConfigManager.normalizeConfig(parsed);
    if (!config) {
      root.status = I18n.tr("\"{0}\" is not a valid config", fileName);
      return;
    }
    const title = String(parsed._example?.title ?? "") || fileName.replace(/\.json$/, "");
    // A file with no personal parts loads with their defaults, which taking
    // them would put in place of the user's own keybinds and apps
    const schema = ConfigManager.configSchema;
    root.importing = {
      name: sanitize(title) || "import",
      title: title,
      description: String(parsed._example?.description ?? ""),
      path: path,
      config: config,
      hasPersonal: !Utils.deepEqual(ConfigExamples.pick(parsed, schema, true), ConfigExamples.pick(parsed, schema, false))
    };
    root.status = "";
  }

  // Applies `importing` (its personal parts too when `personal`: keybinds,
  // apps, commands), after saving the running config as "before-<name>"
  function confirmImport(personal) {
    const pending = root.importing;
    root.importing = null;
    if (pending)
      _backupThenApply(pending.name, pending.config, personal && pending.hasPersonal);
  }

  function cancelImport() {
    root.importing = null;
  }

  // Writes the running config's look (and personal parts, when `personal`)
  // to ~/axiom-<name>-<date>-<time>.json, holding only what differs from the
  // defaults: a file to share, in the format examples and imports use
  function exportConfig(personal) {
    const schema = ConfigManager.configSchema;
    const config = ConfigManager.config;
    const picked = ConfigExamples.pick(config, schema, personal);
    const title = root.active || "axiom";
    const header = {
      "_example": {
        "title": title,
        "description": ""
      },
      "version": ConfigMigration.currentVersion
    };
    let shared = Object.assign({}, header, ConfigExamples.sparse(picked, schema));
    // Leaving the defaults out must not change what applying it does
    const loaded = ConfigManager.normalizeConfig(shared);
    if (!loaded || !Utils.deepEqual(ConfigExamples.apply(config, loaded, schema, personal), ConfigExamples.apply(config, config, schema, personal))) {
      console.warn("[SavedConfigsManager] The sparse export doesn't load back the same; exporting it whole");
      shared = Object.assign({}, header, picked);
    }
    const now = new Date();
    // To the second, so a later export never replaces an earlier one
    const pad = n => String(n).padStart(2, "0");
    const stamp = [now.getFullYear(), now.getMonth() + 1, now.getDate()].map(pad).join("-") + "-" + [now.getHours(), now.getMinutes(), now.getSeconds()].map(pad).join("");
    _exporter.path = Paths.homeDirectory + "axiom-" + sanitize(title).replace(/ /g, "-") + "-" + stamp + ".json";
    _exporter.setText(JSON.stringify(shared, null, 2) + "\n");
  }

  function _backupThenApply(name, config, personal) {
    if (!config) {
      root.status = I18n.tr("\"{0}\" is not a valid config", name);
      return;
    }
    // One at a time: a second would replace the first's backup mid-write
    if (root._pendingApply) {
      root.status = I18n.tr("Busy, try again");
      return;
    }
    root._pendingApply = {
      name: name,
      config: config,
      personal: personal
    };
    save("before-" + name);
  }

  function _apply(pending) {
    if (!ConfigManager.restoreConfig(ConfigExamples.apply(ConfigManager.config, pending.config, ConfigManager.configSchema, pending.personal))) {
      root.status = I18n.tr("\"{0}\" is not a valid config", pending.name);
      return;
    }
    root._setActive("", null);
    SettingsManager.loadConfig();
    root.status = I18n.tr("Applied \"{0}\". The previous configuration is saved as \"{1}\".", pending.name, "before-" + pending.name);
    console.log("[SavedConfigsManager] Applied", pending.name, pending.personal ? "with personal parts" : "");
  }

  // The parsed example (with its _example header), or null
  function _readExample(name) {
    const content = FileManager.read("file://" + examplesDir + name + ".json");
    if (!content)
      return null;
    try {
      return JSON.parse(content);
    } catch (e) {
      console.error("[SavedConfigsManager] Could not parse example", name + ":", e);
      return null;
    }
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
      root._saving = null;
      root.status = I18n.tr("Saved \"{0}\"", name);
      console.log("[SavedConfigsManager]", root.status);
      const pending = root._pendingApply;
      root._pendingApply = null;
      if (pending)
        root._apply(pending);
    }
    onSaveFailed: error => {
      root._saving = null;
      root._pendingApply = null;
      root.status = I18n.tr("Failed to save \"{0}\"", name);
      console.warn("[SavedConfigsManager] Could not write", path + ":", FileViewError.toString(error));
    }
  }

  property FileView _exporter: FileView {
    blockWrites: true
    atomicWrites: true
    printErrors: false
    onSaved: {
      root.status = I18n.tr("Exported to {0}", Paths.shortenHome(path));
      console.log("[SavedConfigsManager] Exported", path);
    }
    onSaveFailed: error => {
      root.status = I18n.tr("Failed to export to {0}", Paths.shortenHome(path));
      console.warn("[SavedConfigsManager] Could not write", path + ":", FileViewError.toString(error));
    }
  }

  property Process _picker: Process {
    stdout: StdioCollector {
      id: pickedPath
    }
    stderr: StdioCollector {
      onStreamFinished: {
        if (text.trim() !== "")
          console.warn("[SavedConfigsManager] File picker:", text.trim());
      }
    }
    onExited: code => {
      ShellManager.endStepAside("filePicker");
      if (code === 0 && pickedPath.text.trim() !== "")
        root.openImport(pickedPath.text.trim());
      else if (code !== 1)
        root.status = I18n.tr("No file picker could be opened");
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

  property FolderListModel _examplesModel: FolderListModel {
    folder: "file://" + root.examplesDir
    nameFilters: ["*.json"]
    showDirs: false
    sortField: FolderListModel.Name
  }
}
