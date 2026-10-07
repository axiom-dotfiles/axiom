pragma Singleton
import QtQuick

import Quickshell
import Quickshell.Io

import qs.components.methods

/* ConfigManager handles loading, saving, and monitoring the configuration file */
QtObject {
  id: root

  // --- Public ---
  readonly property var config: _config
  readonly property var configSchema: _configSchema
  readonly property string configDir: "../config/user/"
  readonly property string configFile: "config.json"

  // True while config.json on disk is unusable (invalid, or present but
  // unreadable). The shell keeps running on the last good config (or schema
  // defaults at startup) and refuses to save, so the file can't be
  // overwritten before it is fixed. Restoring a saved config clears it.
  readonly property bool savesBlocked: _savesBlocked

  // The greeter (greetd's login screen, greeter.qml) runs read-only on the
  // bundle the user's axiom exports for it (GreeterBundle), never on
  // config.json, and writes nothing. Read from the environment here (as
  // Paths.greeter) since ConfigManager reads no reader.
  readonly property bool greeter: Quickshell.env("AXIOM_GREETER") === "1"
  // Where the greeter's config came from: "bundle", "fallback" (the
  // snapshot taken when the greeter was installed, which its own code
  // wrote) or "defaults"; "" outside the greeter
  readonly property string greeterSource: _greeterSource
  property string _greeterSource: ""

  // Unsaved edits an editor shows live, by top-level section ({ Bars: [...] }).
  // Readers of that section prefer them to `config`; they're never merged
  // into it or saved, so other saves and reloads from disk leave them alone.
  readonly property var previews: _previews

  function setPreview(section, value) {
    const previews = Object.assign({}, root._previews);
    previews[section] = Utils.clone(value);
    root._previews = previews;
  }

  // `value` with the defaults of a schema definition (e.g. "Bar",
  // "OverlayModule") filled in: a new entry for an editor to add
  function withDefaults(value, definition) {
    return SchemaValidation.applyDefaults(value, {
      "$ref": "#/definitions/" + definition
    }, root._configSchema);
  }

  function clearPreview(section) {
    if (!(section in root._previews))
      return;
    const previews = Object.assign({}, root._previews);
    delete previews[section];
    root._previews = previews;
  }

  /**
     * @brief Requests a change to the current theme.
     * This is the official way to change the theme. It updates the internal
     * config object and triggers a save and reload cycle.
     * @param themeName The full name of the theme (e.g., "catppuccin-mocha" or "generated/wallpaper-tonal-dark").
     */
  function setTheme(themeName) {
    if (_config.Appearance.theme === themeName) {
      console.log("[ConfigManager] Theme '" + themeName + "' is already set. No change needed.");
      return;
    }
    console.log("[ConfigManager] Setting theme to '" + themeName + "'");
    _config.Appearance.theme = themeName;
    saveConfig();
  }

  /**
     * @brief Requests a change to a monitor's wallpaper in the config.
     * @param wallpaperUrl The full file URL of the wallpaper.
     * @param monitor The monitor it's set on.
     * @param primary Whether that's the primary monitor, whose wallpaper is
     *        also Appearance.wallpaper.
     */
  function setWallpaper(wallpaperUrl, monitor, primary) {
    const appearance = _config.Appearance;
    if (appearance.wallpapers[monitor] === wallpaperUrl && (!primary || appearance.wallpaper === wallpaperUrl))
      return;
    console.log("[ConfigManager] Setting wallpaper on", monitor, "to", wallpaperUrl);
    appearance.wallpapers[monitor] = wallpaperUrl;
    if (primary)
      appearance.wallpaper = wallpaperUrl;
    saveConfig();
  }

  /**
     * @brief Sets several monitors' wallpapers with one save.
     * @param wallpapers Monitor name -> file URL.
     * @param primary The primary monitor's name, whose wallpaper is also
     *        Appearance.wallpaper.
     */
  function setWallpapers(wallpapers, primary) {
    const appearance = _config.Appearance;
    const monitors = Object.keys(wallpapers).filter(monitor => appearance.wallpapers[monitor] !== wallpapers[monitor] || (monitor === primary && appearance.wallpaper !== wallpapers[monitor]));
    if (monitors.length === 0)
      return;
    console.log("[ConfigManager] Setting wallpapers on", monitors.join(", "));
    for (const monitor of monitors) {
      appearance.wallpapers[monitor] = wallpapers[monitor];
      if (monitor === primary)
        appearance.wallpaper = wallpapers[monitor];
    }
    saveConfig();
  }

  /**
     * @brief Saves the current configuration state to config.json and triggers a reload.
     * @return true if it was written.
     */
  function saveConfig() {
    if (root.greeter)
      return false;
    if (_savesBlocked) {
      console.warn("[ConfigManager] config.json is unusable; not saving until it is fixed (or a saved config is restored).");
      return false;
    }
    try {
      if (!_validateConfig(root._config)) {
        console.error("[ConfigManager] Failed to validate config against schema. Aborting save.");
        return false;
      }
      _write(root._config);
      console.log("[ConfigManager] Saved config.json.");
      forceReload();
      return true;
    } catch (e) {
      console.error("[ConfigManager] An error occurred while saving the configuration:", e);
      return false;
    }
  }

  /**
   * @brief Replaces the running config with `object` and saves it, running
   * it through the load pipeline (prune/defaults/validate) first.
   * @return true if it was valid and written; on false nothing changed.
   */
  function commit(object) {
    if (root.greeter)
      return false;
    if (_savesBlocked) {
      console.warn("[ConfigManager] config.json is unusable; not saving until it is fixed (or a saved config is restored).");
      return false;
    }
    const prepared = _prepareConfig(object);
    if (!prepared) {
      console.error("[ConfigManager] Rejected config: it does not validate against the schema.");
      return false;
    }
    root._config = prepared.config;
    return saveConfig();
  }

  /**
   * @brief Applies a full configuration object to memory without saving to disk.
   */
  function applyConfig(object) {
    _loadObjectToConfig(object);
  }

  /**
   * @brief Replaces the whole config with a parsed config object (e.g. a
   * saved configuration), running it through the same migrate/prune/
   * defaults/validate pipeline as config.json, then saves it. This is an
   * explicit replacement, so it also lifts savesBlocked. The `x-takeover`
   * settings (the Hyprland mode, the lock screen, idle, polkit, the
   * greeter) stay as they are (ConfigExamples.keepTakeovers): only their
   * own cards switch them, which do the takeover or give it back.
   * @return true if the config was valid and saved.
   */
  function restoreConfig(object) {
    if (root.greeter)
      return false;
    const prepared = _prepareConfig(object);
    if (!prepared) {
      console.error("[ConfigManager] Restored config is invalid, keeping the current one.");
      return false;
    }
    root._savesBlocked = false;
    root._config = ConfigExamples.keepTakeovers(prepared.config, root._config, _configSchema);
    return saveConfig();
  }

  /**
   * @brief The config a parsed object would load as (migrated, pruned,
   * defaults filled), or null if it doesn't validate. Only computes: it
   * logs nothing, stores no migrated secrets and leaves `object` as it was.
   */
  function normalizeConfig(object) {
    const migrated = ConfigMigration.migrate(Utils.clone(object)).config;
    SchemaValidation.pruneUnknown(migrated, _configSchema);
    const config = SchemaValidation.applyDefaults(migrated, _configSchema);
    return SchemaValidation.validateAgainstSchema(config, _configSchema) ? config : null;
  }

  /**
     * @brief Manually triggers the file checker, simulating a file-system change.
     */
  function forceReload() {
    _fileHashes = {};
    _checkConfigFile();
  }

  /**
     * @brief Discards in-memory edits by reloading config.json from disk.
     * Keeps the current config if the file is unusable.
     */
  function hardResetConfig() {
    const result = _readConfig();
    if (result.status === "ok")
      root._config = result.config;
  }

  // --- Private Implementation ---
  Component.onCompleted: {
    console.log("[ConfigManager] ♻ ConfigManager service started.");
    if (!root.greeter)
      _checkConfigFile();
  }

  // Loaded eagerly (synchronous reads) so the config readers never see a
  // partially-filled config: every key has its schema default from the
  // very first evaluation.
  property var _configSchema: _loadSchema()
  property var _config: _initialConfig(_loadSchema())
  property bool _savesBlocked: false
  property var _previews: ({})
  // Whether the running config came from config.json (vs schema defaults)
  property bool _haveFileConfig: false

  property string _configSchemaPath: "../config/json/config.schema.json"
  property string _configPath: root.configDir + root.configFile

  // FileView only for writing the config
  property FileView _configFileView: FileView {
    path: Qt.resolvedUrl(root.configDir + root.configFile)
    blockWrites: true
    atomicWrites: true
    onSaveFailed: error => {
      console.error("[ConfigManager] Failed to save config.json. Error: " + FileViewError.toString(error));
    }
  }

  // Change notification for config.json. The slow poll is only a safety
  // net in case the watch is lost (e.g. to an editor's atomic rename).
  property FileView _configWatch: FileView {
    path: root.greeter ? "" : Qt.resolvedUrl(root._configPath)
    watchChanges: true
    printErrors: false
    onFileChanged: {
      reload();
      root._checkConfigFile();
    }
  }

  property var _fileHashes: ({})

  property Timer _pollTimer: Timer {
    interval: 5000
    running: !root.greeter
    repeat: true
    onTriggered: root._checkConfigFile()
  }

  function _hashString(str) {
    let hash = 0;
    if (!str || str.length === 0)
      return hash;
    for (let i = 0; i < str.length; i++) {
      hash = ((hash << 5) - hash) + str.charCodeAt(i);
      hash = hash & hash;
    }
    return hash.toString();
  }

  function _getFileContent(filepath) {
    return FileManager.read(Qt.resolvedUrl(filepath));
  }

  function _loadSchema() {
    const content = _getFileContent(_configSchemaPath);
    console.log("[ConfigManager] Loading config schema from", _configSchemaPath);
    if (content) {
      try {
        return JSON.parse(content);
      } catch (e) {
        console.error("[ConfigManager] Failed to parse config.schema.json:", e);
      }
    }
    return {};
  }

  function _validateConfig(config, schema = _configSchema) {
    if (SchemaValidation.validateAgainstSchema(config, schema)) {
      console.log("[ConfigManager] Schema validation passed.");
      return true;
    } else {
      console.error("[ConfigManager] Schema validation failed.");
      return false;
    }
  }

  /**
   * Load pipeline: parse → migrate old layouts → drop unknown keys → fill
   * schema defaults → validate.
   * @return { status, content, config, migrated }; status is "ok",
   *   "empty" (missing, unreadable or mid-write) or "invalid".
   */
  function _readConfig(schema = _configSchema) {
    const content = _getFileContent(configDir + configFile);
    if (!content)
      return {
        status: "empty",
        content: ""
      };

    let parsed;
    try {
      parsed = JSON.parse(content);
    } catch (e) {
      console.error("[ConfigManager] Failed to parse config.json:", e);
      return {
        status: "invalid",
        content: content
      };
    }

    const prepared = _prepareConfig(parsed, schema);
    if (!prepared)
      return {
        status: "invalid",
        content: content
      };
    return {
      status: "ok",
      content: content,
      config: prepared.config,
      migrated: prepared.migrated
    };
  }

  // The config for the very first evaluation. Anything but a good file
  // gives schema defaults; the first _checkConfigFile() then decides
  // whether that means first run (write defaults) or blocking saves.
  function _initialConfig(schema) {
    if (root.greeter)
      return _greeterConfig(schema);
    console.log("[ConfigManager] Loading configuration from", configDir + configFile);
    const result = _readConfig(schema);
    if (result.status !== "ok")
      return SchemaValidation.applyDefaults({}, schema);
    // Remember what was loaded, so the first check doesn't load it again
    if (_fileHashes)
      _fileHashes.config = _hashString(result.content);
    if (result.migrated)
      Qt.callLater(() => _write(result.config));
    console.log("[ConfigManager] Configuration loaded and validated successfully.");
    return result.config;
  }

  // Migrate → prune unknown keys → fill defaults → validate a parsed config.
  // Returns { config, migrated }, or null if the result is invalid.
  function _prepareConfig(parsed, schema = _configSchema) {
    const migration = ConfigMigration.migrate(parsed);
    if (migration.migrated) {
      console.log("[ConfigManager] Migrated config to version", ConfigMigration.currentVersion + ":");
      migration.changes.forEach(change => console.log("  - " + change));
    }
    if (Object.keys(migration.secrets).length > 0 && !root.greeter)
      SecretsManager.store(migration.secrets);

    const config = migration.config;
    const removed = SchemaValidation.pruneUnknown(config, schema);
    removed.forEach(path => console.warn("[ConfigManager] Ignoring unknown config key:", path));

    const filled = SchemaValidation.applyDefaults(config, schema);
    if (!_validateConfig(filled, schema))
      return null;
    return {
      config: filled,
      migrated: migration.migrated
    };
  }

  // Writes a config object to disk as-is (no reload); used after migration
  function _write(config) {
    if (root.greeter)
      return;
    _configFileView.setText(JSON.stringify(config, null, 2));
  }

  // The greeter's config: the bundle (unless AXIOM_GREETER_SAFE, the
  // session script's second try after the greeter failed), else the
  // snapshot its install took (fallback/ in the installed copy, written
  // by this same code, so it always loads), else the schema's defaults.
  // A bundle from a newer axiom than this copy is still tried: unknown
  // keys are dropped, and only what breaks validation falls through.
  function _greeterConfig(schema) {
    const bundleDir = (Quickshell.env("AXIOM_GREETER_DIR") || "/var/lib/axiom-greeter") + "/config/";
    const candidates = [];
    if (Quickshell.env("AXIOM_GREETER_SAFE") !== "1")
      candidates.push({
        "source": "bundle",
        "text": FileManager.read("file://" + bundleDir + "greeter.json")
      });
    candidates.push({
      "source": "fallback",
      "text": _getFileContent("../fallback/greeter.json")
    });
    const picked = GreeterBundle.pick(candidates, raw => {
      const prepared = _prepareConfig(raw, schema);
      return prepared ? {
        "config": prepared.config,
        "errors": []
      } : {
        "config": null,
        "errors": ["does not validate against the schema"]
      };
    }, () => SchemaValidation.applyDefaults({}, schema));
    picked.problems.forEach(problem => console.warn("[ConfigManager] Greeter config from the " + problem.source + " not used:", problem.error));
    console.log("[ConfigManager] Greeter config from the", picked.source);
    root._greeterSource = picked.source;
    return picked.config;
  }

  function _loadObjectToConfig(object) {
    if (_validateConfig(object)) {
      // Deep clone so this is always a new object reference, otherwise QML
      // won't emit a change signal when the same localConfig object (mutated
      // in place across edits) is re-applied, and live updates after the
      // first change silently stop working.
      root._config = Utils.clone(object);
    }
  }

  function _blockSaves(reason) {
    if (_savesBlocked)
      return;
    _savesBlocked = true;
    console.error("[ConfigManager] config.json is " + reason + "; keeping the current config and blocking saves until it is fixed.");
  }

  // Set when there was no config.json at all: a first run (the onboarder
  // starts from it). Not after a reload, when the defaults are on disk.
  readonly property bool firstRun: _firstRun
  property bool _firstRun: false

  // An empty read is either a missing file (first run: write defaults) or a
  // file caught mid-write / unreadable. Only a real "missing" writes.
  property Process _existsCheck: Process {
    command: ["test", "-e", decodeURIComponent(Qt.resolvedUrl(root._configPath).toString().replace("file://", ""))]
    onExited: exitCode => {
      if (exitCode !== 0) {
        console.log("[ConfigManager] No config.json found, writing defaults.");
        root._firstRun = true;
        root._savesBlocked = false;
        root._write(SchemaValidation.applyDefaults({}, root._configSchema));
      } else if (!root._haveFileConfig) {
        // Never loaded a good file: running on defaults, so don't save them over it
        root._blockSaves("empty or unreadable");
      }
    }
  }

  function _checkConfigFile() {
    const content = _getFileContent(_configPath);
    if (!content) {
      // Keep whatever is running; _existsCheck decides whether this is a
      // first run (write defaults) or a file we must not overwrite
      if (!_haveFileConfig && !_existsCheck.running)
        _existsCheck.running = true;
      return false;
    }
    const hash = _hashString(content);
    if (_fileHashes.config === hash) {
      // Same content as the last good load (e.g. a broken edit reverted)
      _haveFileConfig = true;
      _savesBlocked = false;
      delete _fileHashes.invalid;
      return false;
    }
    // Already reported this exact broken content
    if (_fileHashes.invalid === hash)
      return false;

    const result = _readConfig();
    if (result.status !== "ok") {
      _fileHashes.invalid = hash;
      _blockSaves("invalid");
      return false;
    }
    if (_fileHashes.config !== undefined)
      console.log("[ConfigManager] Config file changed, reloading...");
    _fileHashes.config = hash;
    delete _fileHashes.invalid;
    _haveFileConfig = true;
    _savesBlocked = false;
    root._config = result.config;
    if (result.migrated)
      Qt.callLater(() => _write(result.config));
    return true;
  }
}
