pragma Singleton
import QtQuick

// TODO: move this to the configManager
QtObject {
  id: settingsMenu

  property var localConfig: ({})
  property bool isDirty: false
  property bool isStaged: false

  Component.onCompleted: {
    loadConfig();
  }

  function loadConfig() {
    localConfig = {};
    localConfig = JSON.parse(JSON.stringify(ConfigManager.config));
  }

  function checkDirty() {
    return JSON.stringify(localConfig) !== JSON.stringify(ConfigManager.config);
  }

  function stageChanges() {
    ConfigManager.stageConfig(localConfig);
    isStaged = true;
  }

  function continueStaging() {
    if (isStaged) {
      ConfigManager.stageConfig(localConfig);
    }
  }

  function markDirty() {
    settingsMenu.isDirty = checkDirty();
  }

  function unstageChanges() {
    ConfigManager.forceReload();
    isStaged = false;
  }

  function saveChanges() {
    ConfigManager.saveConfig();
    isStaged = false;
    isDirty = false;
    loadConfig();
  }

  function resetChanges() {
    console.log("Resetting changes");
    ConfigManager.hardResetConfig();
    isStaged = false;
    isDirty = false;
    loadConfig();
  }
}
