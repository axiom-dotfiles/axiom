// services/ThemeManager.qml
pragma Singleton

import QtQuick
import Qt.labs.folderlistmodel
import QtCore
import Quickshell
import Quickshell.Io

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

  // This is the correct way to access state without modifying it directly.
  readonly property var config: ConfigManager.config
  readonly property var currentTheme: ConfigManager.theme
  readonly property bool isGeneratedTheme: ConfigManager.isGeneratedTheme

  //=========================================================================
  // Signals
  //=========================================================================
  signal themesReloaded
  signal generationStatusChanged
  signal generationFailed(string errorText)

  //=========================================================================
  // Public Functions (API for your Settings UI)
  //=========================================================================

  /**
   * @brief Applies a theme by name and runs integration scripts.
   * This function now correctly requests the change from ConfigManager.
   */
  function applyTheme(themeName, isGenerated) {
    const fullThemeName = isGenerated ? "generated/" + themeName : themeName;

    if (ConfigManager.config.Appearance && ConfigManager.config.Appearance.theme === fullThemeName) {
        console.log("[ThemeManager] Theme", fullThemeName, "is already applied.");
        return;
    }

    console.log("[ThemeManager] Requesting to apply theme:", fullThemeName);
    // 1. Request the state change from the single source of truth.
    // ConfigManager will handle saving the config and reloading the theme data.
    ConfigManager.setTheme(fullThemeName);

    // 2. Run associated side-effect scripts for theme integration.
    // This is the ThemeManager's responsibility.
    const themePath = _themesPath + "/" + fullThemeName + ".json";
    if (true) { // Replace with actual config checks, e.g., config.Integrations.kitty
      kittyProcess.command = [_configPath + "/scripts/theme_kitty.sh", themePath];
      kittyProcess.running = true;
    }
    if (true) { // e.g., config.Integrations.k9s
      k9sProcess.command = [_configPath + "/scripts/theme_k9s.sh", themePath];
      k9sProcess.running = true;
    }
    if (true) { // e.g., config.Integrations.cava
      cavaProcess.command = [_configPath + "/scripts/theme_cava.sh", themePath];
      cavaProcess.running = true;
    }
  }

  /**
   * @brief Sets the wallpaper in the config AND starts the theme generation process.
   * This is the main entry point for creating a new theme from an image.
   */
  function setWallpaperAndGenerate(wallpaperUrl) {
    console.log("ThemeManager: Setting wallpaper and generating themes from:", wallpaperUrl.toString());

    // Step 1: Tell ConfigManager to update the wallpaper path. It will save the config.
    ConfigManager.setWallpaper(wallpaperUrl.toString());

    // Step 2: Start the theme generation process using the same wallpaper.
    generateThemesFromWallpaper(wallpaperUrl);
  }

  /**
   * @brief Kicks off the python script to generate themes from a wallpaper.
   * This function is now purely for generation and does not modify config itself.
   */
  function generateThemesFromWallpaper(wallpaperUrl) {
    if (isGenerating) {
        console.log("ThemeManager: Generation already in progress.");
        return;
    }
    console.log("ThemeManager: Starting generation process for:", wallpaperUrl.toString());
    _generationController.start(wallpaperUrl);
  }

  function toggleDarkMode() {
    console.log("ThemeManager: toggleDarkMode called.");
    // Accessing readonly properties from ConfigManager is correct.
    const pairedThemeName = currentTheme.paired;

    if (config.Appearance.autoThemeSwitch && pairedThemeName) {

      console.log("Switching theme from '" + config.Appearance.theme + "' to '" + pairedThemeName + "'");
      
      config.Appearance.darkMode = !config.Appearance.darkMode;

      const isPairedThemeGenerated = config.Appearance.theme.startsWith("generated/");

      console.log("Applying paired theme:", pairedThemeName, "Generated:", isPairedThemeGenerated);
      
      applyTheme(pairedThemeName, isPairedThemeGenerated);

    } else {
      if (!config.Appearance.autoThemeSwitch)
        console.log("Auto theme switching is disabled.");
      if (!pairedThemeName)
        console.log("Current theme has no paired theme.");
    }
  }

  /**
   * @brief Forces a reload of configuration and themes via ConfigManager.
   */
  function hardReloadThemes() {
    console.log("ThemeManager: Triggering manual reload via ConfigManager.");
    ConfigManager.forceReload();
  }

  //=========================================================================
  // Private Implementation
  //=========================================================================
  Component.onCompleted: {
    console.log("♻ ThemeManager service started.");
    _reloadAllThemes();
  }

  // --- Paths and Models ---
  property string _configPath: StandardPaths.writableLocation(StandardPaths.AppConfigLocation) + "/axiom"
  property string _themesPath: _configPath + "/config/themes"
  property string _generatedThemesPath: _themesPath + "/generated"
  property string _pythonScriptPath: _configPath + "/scripts/generate_theme.py"

  property ListModel _allThemesModel: ListModel {}
  property ListModel _defaultThemesModel: ListModel {}
  property ListModel _generatedThemesModel: ListModel {}

  property bool _defaultThemesLoaded: false
  property bool _generatedThemesLoaded: false

  // --- Processes ---
  property Process _k9sProcess: Process {
    id: k9sProcess
    stderr: StdioCollector{}
    stdout: StdioCollector{}
  }
  property Process _cavaProcess: Process {
    id: cavaProcess
    stderr: StdioCollector{}
    stdout: StdioCollector{}
  }
  property Process _kittyProcess: Process {
    id: kittyProcess
    stderr: StdioCollector{}
    stdout: StdioCollector{}
  }

  // --- Generation Logic ---
  property QtObject _generationController: QtObject {
    id: _generationController
    property int index: 0
    property url wallpaperUrl
    readonly property var backends: ["wal", "colorz", "colorthief", "haishoku"]

    function start(url) {
      wallpaperUrl = url;
      index = 0;
      runNext();
    }

    function runNext() {
      // if (index >= backends.length) {
      //   console.log("ThemeManager: Theme generation finished successfully.");
      //   // After generation, we want to apply the first theme created.
      //   // We connect to themesReloaded, which fires after the models are populated.
      //   // This ensures the model has data before we try to read from it.
      //   themesReloaded.connect(function applyFirstTheme() {
      //     themesReloaded.disconnect(applyFirstTheme); // Important: Run only once
      //     if (_generatedThemesModel.count > 0) {
      //       const firstThemeName = _generatedThemesModel.get(0).name;
      //       console.log("ThemeManager: Automatically applying first generated theme:", firstThemeName);
      //       // Apply the theme. The second argument 'true' marks it as a generated theme.
      //       applyTheme(firstThemeName, true);
      //     }
      //   });
      //   // Now, trigger the reload which will populate the models and emit themesReloaded.
      //   _reloadAllThemes();
      //   return;
      // }

      const backend = backends[index];
      const themeIndex = index + 1;
      const wallpaperPath = wallpaperUrl.toString().replace("file://", "");
      const scriptPath = root._pythonScriptPath.replace("file://", "");
      const outputDir = root._generatedThemesPath.replace("file://", "");

      console.log("ThemeManager: Generating theme", themeIndex, "using backend:", backend);
      generationProcess.command = ["python3", scriptPath, wallpaperPath, "--output_dir", outputDir, "--backend", backend];
      console.log("ThemeManager: Executing:", generationProcess.command.join(" "));
      generationProcess.running = true;
    }

    function onProcessFinished(success, errorText) {
      if (success) {
        index++;
        if (index >= backends.length) {
          console.log("ThemeManager: Theme generation finished successfully.");
          // // After generation, we want to apply the first theme created.
          // // We connect to themesReloaded, which fires after the models are populated.
          // // This ensures the model has data before we try to read from it.
          // themesReloaded.connect(function applyFirstTheme() {
          //   themesReloaded.disconnect(applyFirstTheme); // Important: Run only once
          //   if (_generatedThemesModel.count > 0) {
          //     const firstThemeName = _generatedThemesModel.get(0).name;
          //     console.log("ThemeManager: Automatically applying first generated theme:", firstThemeName);
          //     // Apply the theme. The second argument 'true' marks it as a generated theme.
          //     applyTheme(firstThemeName, true);
          //   }
          // });
          // // Now, trigger the reload which will populate the models and emit themesReloaded.
          _reloadAllThemes();
          return;
        }
        runNext();
      } else {
        console.error("ThemeManager: Script execution failed.", errorText);
        root.generationFailed(errorText);
      }
    }
  }

  property Process _generationProcess: Process {
    id: generationProcess
    onRunningChanged: root.generationStatusChanged()
    stdout: StdioCollector{ id: stdoutCollector }
    stderr: StdioCollector{ id: stderrCollector }
    onExited: (exitCode, exitStatus) => {
      const success = (exitStatus === 0 && exitCode === 0);
      _generationController.onProcessFinished(success, stderrCollector.text);
    }
  }

  // --- Theme List Loading ---

  /**
   * @brief Clears all theme models and re-triggers the FolderListModels to scan their directories.
   * This is the central function for refreshing the UI lists of themes.
   */
  function _reloadAllThemes() {
    console.log("ThemeManager: Reloading all theme models...");
    _defaultThemesLoaded = false;
    _generatedThemesLoaded = false;
    _allThemesModel.clear();
    _defaultThemesModel.clear();
    _generatedThemesModel.clear();

    // FIX: To reliably trigger a reload of a FolderListModel, you must first set its
    // folder property to an invalid/empty path, and then set it to the correct path.
    // The previous code had a typo where it set _generatedThemeLoader twice.
    _defaultThemeLoader.folder = "";
    _generatedThemeLoader.folder = "";

    // Now set the correct paths to trigger the scan.
    _defaultThemeLoader.folder = _themesPath;
    _generatedThemeLoader.folder = _generatedThemesPath;
  }

  function _checkIfReloadComplete() {
    if (_defaultThemesLoaded && _generatedThemesLoaded) {
      themesReloaded();
      console.log("[ThemeManager] All themes reloaded. Total themes:", _allThemesModel.count);
    }
  }

  // This model loads all themes from the base 'themes' directory, skipping the 'generated' sub-directory.
  property FolderListModel _defaultThemeLoader: FolderListModel {
    nameFilters: ["*.json"]; showDirs: false
    onStatusChanged: {
      if (status === FolderListModel.Ready) {
        for (let i = 0; i < count; i++) {
          // Add a guard to prevent themes from the 'generated' subfolder being added here.
         if (get(i, "fileName") === "generated") continue;

          root._defaultThemesModel.append({ name: get(i, "fileBaseName"), filePath: get(i, "filePath"), isGenerated: false });
          root._allThemesModel.append({ name: get(i, "fileBaseName"), filePath: get(i, "filePath"), isGenerated: false });
        }
        root._defaultThemesLoaded = true;
        // root._checkIfReloadComplete();
        if (root._defaultThemesModel.count === 0) {
          // console.warn("[ThemeManager] No default themes found in:", root._themesPath);
        } else {
          console.log("[ThemeManager] Default themes loaded:", root._defaultThemesModel.count);
        }
      }
    }
  }

  // This model specifically loads themes from the 'themes/generated' directory.
  property FolderListModel _generatedThemeLoader: FolderListModel {
    nameFilters: ["*.json"]; showDirs: false
    onStatusChanged: {
      if (status === FolderListModel.Ready) {
        for (let i = 0; i < count; i++) {
          const fileName = get(i, "fileBaseName");
          if (fileName === "pywal-dark") continue; // Example filter
          root._generatedThemesModel.append({ name: fileName, filePath: get(i, "filePath"), isGenerated: true });
          root._allThemesModel.append({ name: fileName, filePath: get(i, "filePath"), isGenerated: true });
        }
        root._generatedThemesLoaded = true;
        // root._checkIfReloadComplete();
        if (root._generatedThemesModel.count === 0) {
          // console.warn("[ThemeManager] No generated themes found in:", root._generatedThemesPath);
        } else {
          console.log("[ThemeManager] Generated themes loaded:", root._generatedThemesModel.count);
        }
      }
    }
  }
}
