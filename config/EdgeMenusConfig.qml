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

  // The menu's box colours
  function colorsOf(menu) {
    return {
      "fill": Theme.resolveColor(menu?.backgroundColor ?? "base00"),
      "stroke": Theme.resolveColor(menu?.borderColor ?? "base05")
    };
  }

  // The menu's length along its edge, from config alone (for the hover
  // strip before the menu has ever been loaded): its columns side by side
  // at its card size, as EdgeMenuBody lays them out, plus its padding
  function lengthOf(menu, vertical) {
    const unit = menu?.cardSize ?? OverlayConfig.minCardUnit;
    const flows = (menu?.columns ?? []).map(column => OverlayConfig.columnFlow(column.cells, unit));
    const length = vertical ? Math.max(0, ...flows.map(flow => flow.height)) : flows.reduce((sum, flow) => sum + flow.width, 0) + Math.max(0, flows.length - 1) * OverlayConfig.cardSpacing;
    return length + (menu?.padding ?? 0) * 2;
  }
}
