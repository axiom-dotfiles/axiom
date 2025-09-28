pragma Singleton

import QtQuick
import Qt.labs.folderlistmodel
import QtCore

// Import the Quickshell types
import Quickshell.Io

import qs.config
import qs.components.methods
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
    signal generationFailed(string errorText)

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
        console.log("Updated wallpaper in config:", Config.wallpaper)

        // Start the generation process
        _generationController.start(wallpaperUrl)
    }

    /**
     * Applies a theme by setting its name in the global configuration.
     * The Theme.qml singleton will react to this change automatically.
     */
    function applyTheme(themeName) {
        determineGenerated(themeName)
        if (Appearance.theme !== themeName) {
            if (Theme.isGenerated) {
              console.log("Applying generated theme:", themeName)
              Appearance.theme = "generated/" + themeName;
            } else {
              console.log("Applying default theme:", themeName)
              Appearance.theme = themeName;
            }
        }
    }

    function determineGenerated(themeName) {
      console.log("Determining if theme is generated:", themeName)
      if (themeName.includes("pywal")) {
        console.log("Theme is generated.")
        Theme.isGenerated = true;
      } else {
        console.log("Theme is default.")
        Theme.isGenerated = false;
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

    /**
     * Sets the wallpaper and generates the colors from it
     * @param wallpaperUrl The URL of the wallpaper to set
     */
    function setWallpaperAndGenerate(wallpaperUrl) {
        console.log("ThemeManager: Setting wallpaper and generating themes from:", wallpaperUrl.toString())
        Utils.executeWallpaperScript(wallpaperUrl.toString())
        Config.wallpaper = wallpaperUrl.toString()
        generateThemesFromWallpaper(wallpaperUrl)
    }

    //=========================================================================
    // Private Implementation
    //=========================================================================
    Component.onCompleted: {
        console.log("---------------- THEME MANAGER INITIALIZED ----------------")
        _reloadAllThemes()
    }

    property string _configPath: StandardPaths.writableLocation(StandardPaths.AppConfigLocation) + "/" + Config.userName
    property string _themesPath: _configPath + "/config/themes"
    property string _generatedThemesPath: _themesPath + "/generated"
    property string _pythonScriptPath: _configPath + "/scripts/generate_theme.py"

    property ListModel _allThemesModel: ListModel {}
    property ListModel _defaultThemesModel: ListModel {}
    property ListModel _generatedThemesModel: ListModel {}

    // State for tracking async model loading
    property bool _defaultThemesLoaded: false
    property bool _generatedThemesLoaded: false

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

                // After themes are reloaded, apply the first generated one.
                // This connection is temporary and will be disconnected after one signal emission.
                themesReloaded.connect(function applyFirstTheme() {
                    themesReloaded.disconnect(applyFirstTheme)
                    if (_generatedThemesModel.count > 0) {
                        const firstThemeName = _generatedThemesModel.get(0).name
                        console.log("ThemeManager: Automatically applying first generated theme:", firstThemeName)
                        applyTheme(firstThemeName)
                    }
                })

                _reloadAllThemes()
                return;
            }

            const backend = backends[index]
            const themeIndex = index + 1
            const wallpaperPath = wallpaperUrl.toString().replace("file://", "")
            const scriptPath = _pythonScriptPath.replace("file://", "")
            const outputDir = _generatedThemesPath.replace("file://", "")
            console.log("ThemeManager: Generating theme", themeIndex, "using backend:", backend)
            console.log("Generated themes will be saved to:", _generatedThemesPath)
            console.log("theme index:", themeIndex)

            console.log("Using wallpaper:", wallpaperPath)
            generationProcess.command = [
                "python3", scriptPath, wallpaperPath,
                "--output_dir", outputDir,
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
                root.generationFailed(errorText)
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
        _defaultThemesLoaded = false
        _generatedThemesLoaded = false

        _allThemesModel.clear()
        _defaultThemesModel.clear()
        _generatedThemesModel.clear()

        // FIX: Force the FolderListModel to re-scan the directories.
        // By setting the folder to "" first, we guarantee that the subsequent
        // assignment triggers a full refresh, detecting the newly generated files.
        _defaultThemeLoader.folder = ""
        _generatedThemeLoader.folder = ""

        _defaultThemeLoader.folder = _themesPath
        _generatedThemeLoader.folder = _generatedThemesPath
    }

    function _checkIfReloadComplete() {
        if (_defaultThemesLoaded && _generatedThemesLoaded) {
            // Note: Per user request, sorting is disabled.
            // _sortModel(_allThemesModel)
            themesReloaded()
            console.log("ThemeManager: All theme models reloaded.")
        }
    }

    property FolderListModel _defaultThemeLoader: FolderListModel {
        id: _defaultThemeLoader
        nameFilters: ["*.json"]; showDirs: false

        onStatusChanged: {
            if (status !== FolderListModel.Loading) {
                console.log("DefaultThemeLoader status changed:", status === FolderListModel.Ready ? "Ready" : status, "| URL:", folder);
            }
            if (status === FolderListModel.Ready) {
                console.log("DefaultThemeLoader is ready. Found", count, "files.");
                for (let i = 0; i < count; i++) {
                    const filePath = get(i, "filePath")
                    const fileName = get(i, "fileBaseName")
                    console.log(" -", fileName, "->", filePath)
                    _defaultThemesModel.append({ name: fileName, filePath: filePath })
                    _allThemesModel.append({ name: fileName, filePath: filePath })
                }
                _defaultThemesLoaded = true;
                _checkIfReloadComplete();
            }
        }
    }

    property FolderListModel _generatedThemeLoader: FolderListModel {
        id: _generatedThemeLoader
        nameFilters: ["*.json"]; showDirs: false

        onStatusChanged: {
            if (status !== FolderListModel.Loading) {
                console.log("GeneratedThemeLoader status changed:", status === FolderListModel.Ready ? "Ready" : status, "| URL:", folder);
            }
            if (status === FolderListModel.Ready) {
                console.log("GeneratedThemeLoader is ready. Found", count, "files.");
                for (let i = 0; i < count; i++) {
                    const filePath = get(i, "filePath")
                    const fileName = get(i, "fileBaseName")
                    if (fileName === "pywal-dark") continue;
                    console.log(" -", fileName, "->", filePath)
                    _generatedThemesModel.append({ name: fileName, filePath: filePath })
                    _allThemesModel.append({ name: fileName, filePath: filePath })
                }
                _generatedThemesLoaded = true;
                _checkIfReloadComplete();
                console.log("Generated themes loaded:", _generatedThemesModel.count);
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
