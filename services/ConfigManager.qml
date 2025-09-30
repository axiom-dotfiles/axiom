// services/ConfigManager.qml
pragma Singleton
import QtQuick

import qs.components.methods

QtObject {
    id: root

    // --- Public API ---
    // REVISED: Properties are now readonly. Changes must go through public functions.
    // This establishes ConfigManager as the single source of truth.
    readonly property var config: _config
    readonly property var theme: _theme
    readonly property bool isGeneratedTheme: (_theme.name && _theme.name.toLowerCase().includes("pywal"))

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
            _config.Appearance.theme = themeName;
            save(); // Save the change and trigger a reload.
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

            save(); // Save the change and trigger a reload.
        } else {
            console.error("ConfigManager: Cannot set wallpaper, _config.Config is not defined.");
        }
    }

    /**
     * @brief "Saves" the current configuration state and triggers a reload.
     * In a real app, this writes to a file. Here, it just triggers the reload cycle.
     */
    function save() {
        console.log("ConfigManager: Pretending to save config.json...");
        // console.log(JSON.stringify(root._config, null, 2));
        // forceReload();
    }

    /**
     * @brief Manually triggers the file checker, simulating a file-system change.
     */
    function forceReload() {
        console.log("⟳ Manual reload triggered");
        _fileHashes = {}; // Clear hashes to ensure a full reload
        _checkForChanges();
    }

    // --- Private Implementation ---
    // Internal "writable" versions of the public properties
    property var _config: ({})
    property var _theme: ({})

    property int _pollInterval: 1000
    property var _fileHashes: ({})

    property Timer _pollTimer: Timer {
        interval: _pollInterval
        running: true
        repeat: true
        onTriggered: _checkForChanges()
    }

    function _hashString(str) {
        var hash = 0;
        if (!str || str.length === 0) return hash;
        for (var i = 0; i < str.length; i++) {
            var chars = str.charCodeAt(i);
            hash = ((hash << 5) - hash) + chars;
            hash = hash & hash; // Convert to 32bit integer
        }
        return hash.toString();
    }

    function _getFileContent(filepath) {
        try {
            var xhr = new XMLHttpRequest();
            xhr.open("GET", Qt.resolvedUrl(filepath), false);
            xhr.send();
            if (xhr.status === 200 || xhr.status === 0) { // status 0 for local files
                return xhr.responseText;
            }
        } catch (e) {
            console.error("Could not read file:", filepath, e);
        }
        return null;
    }

    function _loadConfig() {
        var content = _getFileContent("../config/config.json");
        if (content) {
            try { return JSON.parse(content); } catch (e) { console.error("Failed to parse config.json:", e); }
        }
        return { Config:{}, Display:{}, Appearance:{}, Bar:{}, Widget:{} };
    }

    function _loadTheme(themeName) {
        var path = "../config/themes/" + themeName + ".json";
        var content = _getFileContent(path);
        if (content) {
            try { return JSON.parse(content); } catch (e) { console.error("Failed to load theme:", themeName, e); }
        }
        return { name: "Default (fallback)", variant: "dark", colors: { base00: "#1a1a1a" }, semantic: { background: "base00" } };
    }

    function _checkForChanges() {
        var hasConfigChanged = false;
        var hasThemeChanged = false;
        var currentThemeName = root._config.Appearance ? root._config.Appearance.theme : "default";

        // 1. Check config.json
        var configContent = _getFileContent("../config/config.json");
        if (configContent !== null) {
            var configHash = _hashString(configContent);
            if (_fileHashes.config !== configHash) {
                if (_fileHashes.config !== undefined) console.log("✓ Config file changed, reloading...");
                _fileHashes.config = configHash;
                root._config = _loadConfig(); // Update internal property
                hasConfigChanged = true;
            }
        }

        // 2. Check current theme file
        var newThemeName = root._config.Appearance ? root._config.Appearance.theme : "default";
        var themeContent = _getFileContent("../config/themes/" + newThemeName + ".json");
        if (themeContent !== null) {
            var themeHash = _hashString(themeContent);
            var themeKey = "theme_" + newThemeName;

            // Reload theme if its content changed OR if the config itself changed (which might mean the theme *name* changed)
            if (_fileHashes[themeKey] !== themeHash || hasConfigChanged) {
                if (_fileHashes[themeKey] !== undefined && !hasConfigChanged) console.log("✓ Theme file '" + newThemeName + "' changed, reloading...");
                _fileHashes[themeKey] = themeHash;
                root._theme = _loadTheme(newThemeName); // Update internal property
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
        // if (hasConfigChanged) root.configChanged();
        // if (hasThemeChanged) root.themeChanged();
    }

    Component.onCompleted: {
        console.log("♻ ConfigManager service started.");
        // Perform initial load and hash
        _checkForChanges();
    }
}
