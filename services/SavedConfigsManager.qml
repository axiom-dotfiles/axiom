pragma Singleton
import QtQuick
import Qt.labs.folderlistmodel
import Quickshell.Io

import qs.config
import qs.components.methods

/**
 * Named snapshots of the config, one JSON file each in $XDG_CONFIG_HOME/axiom/saved/.
 * A snapshot holds what ConfigExamples.snapshot picks: the look and personal
 * parts (by the schema's x-scope) and the wallpaper setup (x-snapshot:
 * wallpapers, mode, rotation, light/dark ones, theme schedule), in the
 * export format, so a saved file can be shared or imported as it is.
 * Restoring applies it like an example, plus the wallpaper setup (other
 * machine settings stay as they are; a wallpaper only if its file is still
 * there), through ConfigManager's load pipeline, so
 * snapshots from older config versions (and older whole-config snapshots)
 * are migrated. The one last saved or restored is `active`, and `modified`
 * says whether the running config's snapshot parts have changed since.
 *
 * Also shares configs (ConfigExamples, by the schema's x-scope): applies
 * the example setups shipped in examples/ and imported files (the running
 * config is first saved as "before-<name>", then the file's look and layout
 * replace the running ones), and exports the running config's look to the
 * home folder in the same format. Nothing loaded changes a takeover setting
 * (the schema's x-takeover: the compositor mode, lock screen, idle, polkit,
 * greeter; ConfigManager.restoreConfig keeps them).
 */
QtObject {
  id: root

  readonly property string savedDir: Paths.userConfigPath + "saved/"
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
  // Whether the running config's snapshot parts differ from the active
  // saved one's (machine settings, which restoring doesn't change, are left
  // out)
  readonly property bool modified: active !== "" && _baseline !== null && !Utils.deepEqual(ConfigExamples.snapshot(ConfigManager.config, ConfigManager.configSchema), _baseline)

  property string _active: ""
  // The snapshot parts of the active saved config as it loads (migrated,
  // defaults filled)
  property var _baseline: null
  // The config being written by save(), the new baseline once it's saved
  // (dropped once it's written or fails)
  property var _saving: null
  // An imported file awaiting confirmation: { name, title, description,
  // path, config, hasPersonal } (config loaded: migrated, defaults filled;
  // hasPersonal: the file holds keybinds, apps or commands), or null
  property var importing: null
  // The file picker is open
  readonly property bool picking: FilePickerManager.running

  // An example, import or shared setup was applied as `name` (its backup
  // is "before-<name>"), or failed to be (status says why)
  signal applied(string name)
  signal applyFailed(string name)

  // What to apply once the running config is saved as its backup:
  // { name, config, personal }, or null
  property var _pendingApply: null
  // The snapshot being restored once its wallpapers are checked:
  // { name, path, config }, or null
  property var _restoring: null
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

  // Saves the running config's snapshot parts (including unsaved settings
  // edits) under `name`, replacing any existing snapshot of that name.
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
    // Through an empty path first: a FileView skips setText of the text it
    // last read or wrote (no `saved`), which would leave an apply waiting
    // on this backup forever
    _writer.path = "";
    _writer.path = savedDir + fileName + ".json";
    const schema = ConfigManager.configSchema;
    const header = {
      "_example": {
        "title": fileName,
        "description": ""
      },
      "version": ConfigMigration.currentVersion
    };
    const saved = Object.assign({}, header, ConfigExamples.sparse(ConfigExamples.snapshot(root._saving, schema), schema));
    _writer.setText(JSON.stringify(saved, null, 2) + "\n");
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
    const config = typeof parsed === "object" && parsed !== null && !Array.isArray(parsed) ? root._load(parsed) : null;
    if (!config) {
      root.status = I18n.tr("\"{0}\" is not a valid config", name);
      return;
    }
    if (_wallpaperCheck.running) {
      root.status = I18n.tr("Busy, try again");
      return;
    }
    // Its wallpapers only where their files are still there: find lists
    // the ones that exist (and exits non-zero for the others)
    const paths = ConfigExamples.snapshotFiles(config, ConfigManager.configSchema);
    root._restoring = {
      name: name,
      path: path,
      config: config
    };
    if (paths.length === 0) {
      root._finishRestore([]);
      return;
    }
    _wallpaperCheck.command = ["find"].concat(paths, ["-maxdepth", "0", "-print0"]);
    _wallpaperCheck.running = true;
  }

  // `existing`: the files of the snapshot's wallpapers that are there
  function _finishRestore(existing) {
    const pending = root._restoring;
    root._restoring = null;
    if (!pending)
      return;
    const applied = ConfigExamples.apply(ConfigManager.config, pending.config, ConfigManager.configSchema, true);
    if (!ConfigManager.restoreConfig(ConfigExamples.withSnapshot(applied, pending.config, ConfigManager.configSchema, existing))) {
      root.status = I18n.tr("\"{0}\" is not a valid config", pending.name);
      return;
    }
    root._setActive(pending.name, ConfigManager.config);
    SettingsManager.loadConfig();
    root.status = I18n.tr("Restored \"{0}\"", pending.name);
    console.log("[SavedConfigsManager] Restored", pending.path);
  }

  // Applies the schema defaults like an example (the look and personal
  // parts; machine settings stay), after saving the running config as
  // "before-defaults". The current version skips migration, which would
  // otherwise treat the empty object as a version 1 config.
  function restoreDefaults() {
    _backupThenApply("defaults", ConfigManager.normalizeConfig({
      "version": ConfigMigration.currentVersion
    }), true);
  }

  // A file to apply, loaded (migrated, defaults filled; null if invalid),
  // keeping what an older file never held (ConfigExamples.keepMovedLook)
  function _load(parsed) {
    const config = ConfigManager.normalizeConfig(parsed);
    return config ? ConfigExamples.keepMovedLook(config, ConfigManager.config, parsed.version) : null;
  }

  // Saves the running config as "before-<name>", then applies the example
  // (in _writer's onSaved, so a failed backup applies nothing)
  function applyExample(name) {
    const example = _readExample(name);
    if (!example) {
      root.status = I18n.tr("\"{0}\" could not be read", name);
      return;
    }
    _backupThenApply(name, root._load(example), false);
  }

  // Opens the desktop's file picker; the chosen file goes to openImport
  function browseImport() {
    FilePickerManager.pick(root, I18n.tr("Import a configuration"), {
      "filter": "JSON:*.json"
    }, path => root.openImport(path), () => root.status = I18n.tr("No file picker could be opened"));
  }

  // Loads a shared file (an export, an example, or a whole config.json of
  // any version) as `importing`, for the settings page to confirm
  function openImport(path) {
    root.importing = null;
    const fileName = path.split("/").pop();
    const parsed = root._readShared(path, fileName);
    if (!parsed)
      return;
    const config = root._load(parsed);
    if (!config) {
      root.status = I18n.tr("\"{0}\" is not a valid config", fileName);
      return;
    }
    const title = String(parsed._example?.title ?? "") || fileName.replace(/\.json$/, "");
    // A file with no personal parts loads with their defaults, which taking
    // them would put in place of the user's own keybinds and apps. Read
    // migrated (not filled), so an older file's are found where they are now
    const schema = ConfigManager.configSchema;
    const migrated = ConfigMigration.migrate(parsed).config;
    root.importing = {
      name: sanitize(title) || "import",
      title: title,
      description: String(parsed._example?.description ?? ""),
      path: path,
      config: config,
      hasPersonal: !Utils.deepEqual(ConfigExamples.pick(migrated, schema, true), ConfigExamples.pick(migrated, schema, false))
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

  // Applies a shared file at `path` straight away, its look only (never
  // keybinds, apps or commands), after saving the running config as
  // "before-<name>": a community setup (CommunitySetupsManager). False
  // with `status` saying why when the file can't be applied.
  function applyShared(name, path, title) {
    const parsed = root._readShared(path, title);
    return parsed !== null && root._backupThenApply(name, root._load(parsed), false, title);
  }

  // The parsed shared file at `path`, or null with `status` saying why (as
  // `label`). One without a version would be migrated as a version 1
  // config, which can quietly rewrite a newer layout; a newer one would
  // lose what this version doesn't know.
  function _readShared(path, label) {
    const content = FileManager.read("file://" + path);
    if (!content) {
      root.status = I18n.tr("\"{0}\" could not be read", label);
      return null;
    }
    let parsed;
    try {
      parsed = JSON.parse(content);
    } catch (e) {
      console.warn("[SavedConfigsManager] Could not parse", path + ":", e);
      root.status = I18n.tr("\"{0}\" is not valid JSON", label);
      return null;
    }
    if (typeof parsed !== "object" || parsed === null || Array.isArray(parsed)) {
      root.status = I18n.tr("\"{0}\" is not a valid config", label);
      return null;
    }
    const version = parsed.version;
    if (!Number.isInteger(version) || version < 1) {
      root.status = I18n.tr("\"{0}\" has no config version, so it can't be imported", label);
      return null;
    }
    if (version > ConfigMigration.currentVersion) {
      root.status = I18n.tr("\"{0}\" is from a newer axiom. Update axiom to import it.", label);
      return null;
    }
    return parsed;
  }

  // Writes the running config's look (and personal parts, when `personal`)
  // to ~/axiom-<name>-<date>-<time>.json, holding only what differs from the
  // defaults: a file to share, in the format examples and imports use
  function exportConfig(personal) {
    const schema = ConfigManager.configSchema;
    const header = {
      "_example": {
        "title": root.active || "axiom",
        "description": ""
      },
      "version": ConfigMigration.currentVersion
    };
    // Applies as the whole pick would (tst_ConfigExamples' round trips)
    const shared = Object.assign({}, header, ConfigExamples.sparse(ConfigExamples.pick(ConfigManager.config, schema, personal), schema));
    const now = new Date();
    // To the second, so a later export never replaces an earlier one
    const pad = n => String(n).padStart(2, "0");
    const stamp = [now.getFullYear(), now.getMonth() + 1, now.getDate()].map(pad).join("-") + "-" + [now.getHours(), now.getMinutes(), now.getSeconds()].map(pad).join("");
    const named = root.active ? sanitize(root.active).replace(/ /g, "-") + "-" : "";
    _exporter.path = Paths.homeDirectory + "axiom-" + named + stamp + ".json";
    _exporter.setText(JSON.stringify(shared, null, 2) + "\n");
  }

  // False (with `status` naming it as `label`) when `config` is invalid or
  // another apply is under way
  function _backupThenApply(name, config, personal, label = name) {
    if (!config) {
      root.status = I18n.tr("\"{0}\" is not a valid config", label);
      return false;
    }
    // One at a time: a second would replace the first's backup mid-write
    if (root._pendingApply) {
      root.status = I18n.tr("Busy, try again");
      return false;
    }
    root._pendingApply = {
      name: name,
      config: config,
      personal: personal
    };
    save("before-" + name);
    return true;
  }

  function _apply(pending) {
    if (!ConfigManager.restoreConfig(ConfigExamples.apply(ConfigManager.config, pending.config, ConfigManager.configSchema, pending.personal))) {
      root.status = I18n.tr("\"{0}\" is not a valid config", pending.name);
      root.applyFailed(pending.name);
      return;
    }
    root._setActive("", null);
    SettingsManager.loadConfig();
    root.status = I18n.tr("Applied \"{0}\". The previous configuration is saved as \"{1}\".", pending.name, "before-" + pending.name);
    console.log("[SavedConfigsManager] Applied", pending.name, pending.personal ? "with personal parts" : "");
    root.applied(pending.name);
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
      root._baseline = baseline === null ? null : ConfigExamples.snapshot(baseline, ConfigManager.configSchema);
  }

  function _loadBaseline() {
    root._baseline = null;
    if (root._active === "")
      return;
    const content = FileManager.read("file://" + savedDir + root._active + ".json");
    if (!content)
      return;
    try {
      const config = root._load(JSON.parse(content));
      root._baseline = config ? ConfigExamples.snapshot(config, ConfigManager.configSchema) : null;
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
      const pending = root._pendingApply;
      root._pendingApply = null;
      root.status = I18n.tr("Failed to save \"{0}\"", name);
      if (pending)
        root.applyFailed(pending.name);
      console.warn("[SavedConfigsManager] Could not write", path + ":", FileViewError.toString(error));
    }
  }

  // Which of a restored snapshot's wallpaper files exist
  property Process _wallpaperCheck: Process {
    stdout: StdioCollector {
      onStreamFinished: root._finishRestore(text.split("\0").filter(path => path !== ""))
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
