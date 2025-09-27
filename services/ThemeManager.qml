pragma Singleton

import QtQuick
import Qt.labs.folderlistmodel
import QtCore

// Import the Quickshell types
import Quickshell.Io

import qs.config
import qs.services

QtObject {
    id: root

    //=========================================================================
    // Public Models & State (for UI consumption)
    //=========================================================================
    readonly property FolderListModel wallpaperModel: FolderListModel {
        folder: StandardPaths.writableLocation(StandardPaths.PicturesLocation) + "/wallpapers"
        nameFilters: ["*.jpg", "*.jpeg", "*.png", "*.bmp"]
        showDirs: false
    }
    readonly property ListModel allThemes: _allThemesModel
    readonly property ListModel generatedThemes: _generatedThemesModel
    readonly property ListModel defaultThemes: _defaultThemesModel
    readonly property bool isGenerating: generationProcess.running

    //=========================================================================
    // Signals
    //=========================================================================
    signal themesReloaded()
    signal generationStatusChanged()

    //=========================================================================
    // Public Functions (API for your Settings UI)
    //=========================================================================

    /**
     * Generates 4 new theme sets from the selected wallpaper and applies the first one.
     */
    function generateThemesFromWallpaper(wallpaperUrl) {
        if (isGenerating) return;
        console.log("ThemeManager: Starting theme generation for:", wallpaperUrl.toString())
        Config.wallpaper = wallpaperUrl.toString() // Update wallpaper in config

        // Start the generation process
        _generationController.start(wallpaperUrl)
    }

    /**
     * Applies a theme by setting its name in the global configuration.
     * The Theme.qml singleton will react to this change automatically.
     */
    function applyTheme(themeName) {
        if (Appearance.theme !== themeName) {
            console.log("ThemeManager: Applying theme ->", themeName);
            Appearance.theme = themeName;
        }
    }

    /**
     * Toggles between the current theme and its paired light/dark variant.
     */
    function toggleDarkMode() {
        console.log("ThemeManager: toggleDarkMode called.")

        const pairedTheme = Theme.paired
        console.log("Current theme:", Appearance.theme)
        console.log("Paired theme:", pairedTheme)
        if (Appearance.autoThemeSwitch && pairedTheme) {

            console.log("Switching theme from '" + Appearance.theme + "' to '" + pairedTheme + "'")
            applyTheme(pairedTheme)
        } else {
            if (!Appearance.autoThemeSwitch) console.log("Auto theme switching is disabled.")
            if (!pairedTheme) console.log("Current theme has no paired theme.")
        }
    }

    //=========================================================================
    // Private Implementation
    //=========================================================================
    Component.onCompleted: {
        console.log("ThemeManager initialized.")
        console.log("---------------------------------------")
        _reloadAllThemes()
    }

    property string _configPath: StandardPaths.writableLocation(StandardPaths.AppConfigLocation) + "/" + Config.userName
    property string _themesPath: _configPath + "/themes"
    property string _generatedThemesPath: _themesPath + "/generated"
    property string _pythonScriptPath: _configPath + "/scripts/generate_theme.py"

    property ListModel _allThemesModel: ListModel {}
    property ListModel _defaultThemesModel: ListModel {}
    property ListModel _generatedThemesModel: ListModel {}

    property QtObject _generationController: QtObject {
        id: _generationController
        property int index: 0
        property url wallpaperUrl
        readonly property var backends: ["wal", "colorz", "colorthief", "haishoku"]

        function start(url) {
            wallpaperUrl = url
            index = 0
            runNext()
        }

        function runNext() {
            if (index >= backends.length) {
                console.log("ThemeManager: Theme generation finished successfully.")
                _reloadAllThemes()
                applyTheme("pywal-dark1") // Apply the first generated theme
                return;
            }

            const backend = backends[index]
            const themeIndex = index + 1
            const wallpaperPath = wallpaperUrl.toLocalFile()

            generationProcess.command = [
                "python3", _pythonScriptPath, wallpaperPath,
                "--output_dir", _generatedThemesPath,
                "--index", themeIndex.toString(), "--backend", backend
            ]
            console.log("ThemeManager: Executing:", generationProcess.command.join(" "))
            generationProcess.running = true;
        }

        function onProcessFinished(success, errorText) {
            if (success) {
                index++
                runNext()
            } else {
                console.error("ThemeManager: Script execution failed.", errorText)
            }
        }
    }

    property Process _generationProcess: Process {
        id: generationProcess
        onRunningChanged: generationStatusChanged()
        stderr: StdioCollector { id: stderrCollector }
        onExited: (exitCode, exitStatus) => {
            const success = (exitStatus === 0 /* NormalExit */ && exitCode === 0)
            _generationController.onProcessFinished(success, stderrCollector.text)
        }
    }

    function _reloadAllThemes() {
        _allThemesModel.clear()
        _defaultThemesModel.clear()
        _generatedThemesModel.clear()

        _defaultThemeLoader.folder = "file://" + _themesPath
        _generatedThemeLoader.folder = "file://" + _generatedThemesPath
    }

    property FolderListModel _defaultThemeLoader: FolderListModel {
        id: _defaultThemeLoader
        nameFilters: ["*.json"]; showDirs: false

        onStatusChanged: {
            console.log("Config dir:", _configPath)
            console.log("DefaultThemeLoader status changed:", status === FolderListModel.Ready ? "Ready" : status);
            console.log("Status changed: count =", count);
            console.log("New status:", status);
            console.log("Desired status:", FolderListModel.Ready);
            if (status === FolderListModel.Ready) {
                console.log("DefaultThemeLoader is ready. Found", count, "files.");
                for (let i = 0; i < count; i++) {
                    const filePath = get(i, "filePath")
                    const fileName = get(i, "fileName")
                    console.log("Found default theme file:", fileName);
                    const themeName = fileName.substring(0, fileName.lastIndexOf('.'));
                    console.log("Registering default theme:", themeName);
                    _defaultThemesModel.append({ name: themeName, filePath: filePath })
                    _allThemesModel.append({ name: themeName, filePath: filePath })
                }
                _sortModel(_allThemesModel)
                themesReloaded()
            }
        }
    }

    property FolderListModel _generatedThemeLoader: FolderListModel {
        id: _generatedThemeLoader
        nameFilters: ["*.json"]; showDirs: false

        // FIX: The signal is onStatusChanged, not onModelUpdated.
        onStatusChanged: {
            if (status === FolderListModel.Ready) {
                for (let i = 0; i < count; i++) {
                    const filePath = get(i, "filePath")
                    const fileName = get(i, "fileName")
                    const themeName = fileName.substring(0, fileName.lastIndexOf('.'));
                    _generatedThemesModel.append({ name: themeName, filePath: filePath })
                    _allThemesModel.append({ name: themeName, filePath: filePath })
                }
                _sortModel(_generatedThemesModel)
                _sortModel(_allThemesModel)
                themesReloaded()
            }
        }
    }

    function _sortModel(model) {
        let items = [];
        for (let i = 0; i < model.count; i++) items.push(model.get(i));
        items.sort((a, b) => a.name.localeCompare(b.name, undefined, { numeric: true, sensitivity: 'base' }));
        model.clear();
        items.forEach(item => model.append(item));
    }
}
