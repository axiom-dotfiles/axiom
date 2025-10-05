pragma Singleton
import QtQuick

import Quickshell.Io

import qs.components.methods
import qs.config

QtObject {
  id: configManager

  // --- Public API ---
  // Source of truth for the entire configuration. Probably should have a way to backup config
  // before writing over it.
  readonly property var config: _config
  readonly property var theme: _theme
  readonly property bool isGeneratedTheme: (_theme.name && _theme.name.toLowerCase().includes("generated"))

  // --- Public Methods for State Modification ---

  /**
     * @brief Requests a change to the current theme.
     * This is the official way to change the theme. It updates the internal
     * config object and triggers a save and reload cycle.
     * @param themeName The full name of the theme (e.g., "catppuccin-mocha" or "generated/pywal-1").
     */
  function setTheme(themeName) {
    if (_config.Appearance) {
      if (_config.Appearance.theme === themeName) {
        console.log("ConfigManager: Theme '" + themeName + "' is already set. No change needed.");
        return;
      }
      console.log("ConfigManager: Setting theme to '" + themeName + "'");
      console.log("Previous background: ", Theme.background);
      _config.Appearance.theme = themeName;
      console.log("Requested theme change to:", themeName);
      console.log("New theme: ", Appearance.theme);
      console.log("New background: ", Theme.background);
      saveConfig(); // Save the change and trigger a reload.
    } else {
      console.error("ConfigManager: Cannot set theme, _config.Appearance is not defined.");
    }
  }

  /**
     * @brief Requests a change to the wallpaper path in the config.
     * @param wallpaperUrl The full file URL of the wallpaper.
     */
  function setWallpaper(wallpaperUrl) {
    if (_config.Config) {
      if (_config.Config.wallpaper === wallpaperUrl) {
        return; // No change needed
      }
      console.log("ConfigManager: Setting wallpaper to", wallpaperUrl);
      _config.Config.wallpaper = wallpaperUrl;
      Utils.executeWallpaperScript(wallpaperUrl);

      saveConfig(); // Save the change and trigger a reload.
    } else {
      console.error("ConfigManager: Cannot set wallpaper, _config.Config is not defined.");
    }
  }

  /**
     * @brief Saves the current configuration state to config.json and triggers a reload.
     */
  function saveConfig() {
    console.log("ConfigManager: Writing current configuration to config.json...");
    try {
      var configString = JSON.stringify(configManager._config, null, 2);
      _configFileView.setText(configString);
      console.log("ConfigManager: Save successful.");
      forceReload();
      themeIntegrations(); // Apply theme to enabled integrated tools
    } catch (e) {
      console.error("ConfigManager: An error occurred while saving the configuration:", e);
    }
  }

  /**
   * @brief Applies the currrent theme to enabled integrated tools
   */
  function themeIntegrations() {
    var scriptPath = Config.scriptsPath;
    var themePath = Config.themePath + Appearance.theme + ".json";
    if (_config.ThemeIntegrations.kitty) {
      // use the component process to theme kitty
      if (_kittyProcess.running) {
        console.log("Kitty theming process is already running. Skipping new request.");
        return;
      }
      console.log("Theming Kitty with theme at:", themePath);
      _kittyProcess.command = [scriptPath + "theme_kitty.sh", themePath];
      console.log("Kitty theming command set to:", _kittyProcess.command);
      _kittyProcess.running = true;
    }
    if (_config.ThemeIntegrations.cava) {
      if (_cavaProcess.running) {
        console.log("Cava theming process is already running. Skipping new request.");
        return;
      }
      _cavaProcess.command = [scriptPath + "theme_cava.sh", themePath];
      _cavaProcess.running = true;
    }
    if (_config.ThemeIntegrations.k9s) {
      if (_k9sProcess.running) {
        console.log("K9s theming process is already running. Skipping new request.");
        return;
      }
      _k9sProcess.command = [scriptPath + "theme_k9s.sh", themePath];
      _k9sProcess.running = true;
    }
  }

  /**
     * @brief Manually triggers the file checker, simulating a file-system change.
     */
  function forceReload() {
    console.log("⟳ Manual reload triggered");
    _fileHashes = {};
    _checkForChanges();
  }

  // --- Private Implementation ---
  // Internal "writable" versions of the public properties
  property var _config: ({})
  property var _theme: ({})

  // FileView component to handle reading/writing the config file.
  property FileView _configFileView: FileView {
    path: Qt.resolvedUrl("../config/json/config.json")
    // Block writes to ensure the save is complete before we reload.
    // This prevents race conditions.
    blockWrites: true
    onSaveFailed: error => {
      console.error("ConfigManager: Failed to save config.json. Error: " + FileViewError.toString(error));
    }
  }

  property int _pollInterval: 1000
  property var _fileHashes: ({})

  property Timer _pollTimer: Timer {
    interval: configManager._pollInterval
    running: true
    repeat: true
    onTriggered: configManager._checkForChanges()
  }

  function _hashString(str) {
    var hash = 0;
    if (!str || str.length === 0)
      return hash;
    for (var i = 0; i < str.length; i++) {
      var chars = str.charCodeAt(i);
      hash = ((hash << 5) - hash) + chars;
      hash = hash & hash; // Convert to 32bit integer
    }
    return hash.toString();
  }

  // TODO: use fileview but this is speedy and simple and currenctly works and im lazy
  function _getFileContent(filepath) {
    try {
      var xhr = new XMLHttpRequest();
      xhr.open("GET", Qt.resolvedUrl(filepath), false);
      xhr.send();
      if (xhr.status === 200 || xhr.status === 0) {
        return xhr.responseText;
      }
    } catch (e) {
      console.error("Could not read file:", filepath, e);
    }
    return null;
  }

  function _loadConfig() {
    var content = _getFileContent("../config/json/config.json");
    if (content) {
      try {
        return JSON.parse(content);
      } catch (e) {
        console.error("Failed to parse config.json:", e);
      }
    }
    return {
      Config: {},
      Display: {},
      Appearance: {},
      Bar: {},
      Widget: {}
    };
  }

  function _loadTheme(themeName) {
    var path = "../config/themes/" + themeName + ".json";
    var content = _getFileContent(path);
    if (content) {
      try {
        return JSON.parse(content);
      } catch (e) {
        console.error("Failed to load theme:", themeName, e);
      }
    }
    return {
      name: "Default (fallback)",
      variant: "dark",
      colors: {
        base00: "#1a1a1a"
      },
      semantic: {
        background: "base00"
      }
    };
  }

  function _checkForChanges() {
    var hasConfigChanged = false;
    var hasThemeChanged = false;
    var currentThemeName = configManager._config.Appearance ? configManager._config.Appearance.theme : "default";

    // 1. Check config.json
    var configContent = _getFileContent("../config/json/config.json");
    if (configContent !== null) {
      var configHash = _hashString(configContent);
      if (_fileHashes.config !== configHash) {
        if (_fileHashes.config !== undefined)
          console.log("✓ Config file changed, reloading...");
        _fileHashes.config = configHash;
        configManager._config = _loadConfig(); // Update internal property
        hasConfigChanged = true;
      }
    }

    // 2. Check current theme file
    var newThemeName = configManager._config.Appearance ? configManager._config.Appearance.theme : "default";
    var themeContent = _getFileContent("../config/themes/" + newThemeName + ".json");
    if (themeContent !== null) {
      var themeHash = _hashString(themeContent);
      var themeKey = "theme_" + newThemeName;

      // Reload theme if its content changed OR if the config itself changed (which might mean the theme *name* changed)
      if (_fileHashes[themeKey] !== themeHash || hasConfigChanged) {
        if (_fileHashes[themeKey] !== undefined && !hasConfigChanged)
          console.log("✓ Theme file '" + newThemeName + "' changed, reloading...");
        _fileHashes[themeKey] = themeHash;
        configManager._theme = _loadTheme(newThemeName); // Update internal property
        hasThemeChanged = true;
      }
    }

    // 3. Clear old theme hashes if theme name changed in config
    if (currentThemeName !== newThemeName) {
      for (var key in _fileHashes) {
        if (key.startsWith("theme_") && key !== "theme_" + newThemeName) {
          delete _fileHashes[key];
        }
      }
    }

  // 4. Emit signals
  // if (hasConfigChanged) configManager.configChanged();
  // if (hasThemeChanged) configManager.themeChanged();
  }

  Component.onCompleted: {
    console.log("♻ ConfigManager service started.");
    // Perform initial load and hash
    _checkForChanges();
  }

  // --- Process Launchers for Integrated Tools ---
  // universal component proessess
  property Component processComponent: Component {
    Process {
      id: genericProcess
      running: false

      stdout: StdioCollector {
        id: genericStdout
        onStreamFinished: {
          genericProcess.running = false;
        }
      }

      stderr: StdioCollector {
        id: genericStderr
        onStreamFinished: {
          console.log("Process error:", text);
          genericProcess.running = false;
        }
      }
    }
  }
  property Process _k9sProcess: Process {
    id: k9sProcess
    stderr: StdioCollector {
      id: k9sStderr
    }
    stdout: StdioCollector {
      id: k9sStdout
    }
  }

  property Process _cavaProcess: Process {
    id: cavaProcess
    stderr: StdioCollector {
      id: cavaStderr
    }
    stdout: StdioCollector {
      id: cavaStdout
    }
  }

  property Process _kittyProcess: Process {
    id: kittyProcess
    stderr: StdioCollector {
      id: kittyStderr
    }
    stdout: StdioCollector {
      id: kittyStdout
    }
  }
}
