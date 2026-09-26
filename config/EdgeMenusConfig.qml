pragma Singleton
import QtQuick
import Quickshell
import qs.services

// EdgeMenus: menus that pop out of a screen edge, holding overlay modules.
// While the edge menu editor has unsaved edits, the running menus show
// those (ConfigManager.previews). Named with a Config suffix so the shell
// entry can be `EdgeMenus`.
QtObject {
  id: root

  readonly property var menus: ConfigManager.previews.EdgeMenus ?? ConfigManager.config.EdgeMenus
  readonly property var enabledMenus: root.menus.filter(menu => menu.enabled && menu.id)

  function menuById(id) {
    return root.menus.find(menu => menu.id === id) ?? null;
  }

  // The menu's named screen, else the primary monitor
  function screenFor(menu) {
    const screens = Quickshell.screens;
    return screens.find(s => s.name === menu?.monitor) ?? screens.find(s => s.name === General.primaryMonitor) ?? screens[0] ?? null;
  }

  // The menu's edge as a Bar.Location
  function edgeOf(menu) {
    return Bar.getLocationFromString(menu?.edge ?? "Left");
  }
}
