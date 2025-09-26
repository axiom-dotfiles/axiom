import QtQuick
import Quickshell
import qs.config as ConfigLib
import "ConfigLoader.js" as Loader

Item {
  id: root

  property int pollInterval: 1000 // milliseconds
  property var fileHashes: ({})
  property bool verbose: false // Set to true for debug logging

  Timer {
    interval: pollInterval
    running: true
    repeat: true

    onTriggered: {
      checkForChanges();
    }
  }

  function hashString(str) {
    // Simple hash function for change detection
    var hash = 0;
    if (!str || str.length === 0)
      return hash;

    for (var i = 0; i < str.length; i++) {
      var chars = str.charCodeAt(i);
      hash = ((hash << 5) - hash) + chars;
      hash = hash & hash; // Convert to 32-bit integer
    }
    return hash.toString();
  }

  function getFileContent(filepath) {
    try {
      var xhr = new XMLHttpRequest();
      xhr.open("GET", Qt.resolvedUrl(filepath), false);
      xhr.send();

      if (xhr.status === 200) {
        return xhr.responseText;
      }
    } catch (e) {
      if (verbose)
        console.log("Could not read file:", filepath);
    }
    return null;
  }

  function checkForChanges() {
    var hasChanges = false;

    // Check config.json
    var configPath = "../config.json";
    var configContent = getFileContent(configPath);
    if (configContent !== null) {
      var configHash = hashString(configContent);

      if (fileHashes.config === undefined) {
        // First run
        fileHashes.config = configHash;
        if (verbose)
          console.log("Initial config hash:", configHash);
      } else if (fileHashes.config !== configHash) {
        // Config changed
        console.log("✓ Config file changed, reloading...");
        fileHashes.config = configHash;

        // Reload all config-dependent singletons
        ConfigLib.Config.configData = Loader.loadConfig();
        ConfigLib.Display.configData = Loader.loadConfig();
        ConfigLib.Appearance.configData = Loader.loadConfig();
        ConfigLib.Bar.configData = Loader.loadConfig();
        ConfigLib.Widget.configData = Loader.loadConfig();

        hasChanges = true;
      }
    }

    // Check current theme file
    var themeName = ConfigLib.Appearance.theme;
    var themePath = "../themes/" + themeName + ".json";
    var themeContent = getFileContent(themePath);
    if (themeContent !== null) {
      var themeHash = hashString(themeContent);
      var themeKey = "theme_" + themeName;

      if (fileHashes[themeKey] === undefined) {
        // First run for this theme
        fileHashes[themeKey] = themeHash;
        if (verbose)
          console.log("Initial theme hash for", themeName, ":", themeHash);
      } else if (fileHashes[themeKey] !== themeHash) {
        // Theme changed
        console.log("✓ Theme file changed, reloading...");
        fileHashes[themeKey] = themeHash;
        ConfigLib.Theme.reload();
        hasChanges = true;
      }
    }

    // Clear old theme hashes when theme switches
    for (var key in fileHashes) {
      if (key.startsWith("theme_") && key !== "theme_" + themeName) {
        delete fileHashes[key];
      }
    }

    if (verbose && !hasChanges) {
      console.log("No changes detected");
    }
  }

  // Manual reload function
  function forceReload() {
    console.log("⟳ Manual reload triggered");
    ConfigLib.Config.configData = Loader.loadConfig();
    ConfigLib.Display.configData = Loader.loadConfig();
    ConfigLib.Appearance.configData = Loader.loadConfig();
    ConfigLib.Bar.configData = Loader.loadConfig();
    ConfigLib.Widget.configData = Loader.loadConfig();
    ConfigLib.Theme.reload();

    // Reset hashes to force detection of next change
    fileHashes = {};
  }

  Component.onCompleted: {
    console.log("♻ Hot reload monitor started (checking every", pollInterval, "ms)");
    if (verbose)
      console.log("Watching config.json and theme files for changes");
  }
}
