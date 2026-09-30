pragma Singleton
import QtQuick
import qs.services
import qs.components.methods

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

  // The first enabled menu holding a module of `type`, else null
  function menuWithModule(type) {
    return root.enabledMenus.find(menu => menu.columns.some(column => column.cells.some(cell => Object.values(cell.slots).some(slot => slot?.type === type)))) ?? null;
  }

  // The menu's named screen, else the primary monitor
  function screenFor(menu) {
    return General.screensNamed(menu.monitor)[0] ?? null;
  }

  // The menu's edge as a Bar.Location
  function edgeOf(menu) {
    return Bar.getLocationFromString(menu.edge);
  }

  // The menu's box colours
  function colorsOf(menu) {
    return {
      "fill": Theme.resolveColor(menu.backgroundColor),
      "stroke": Theme.resolveColor(menu.borderColor)
    };
  }

  // Space between the menu's box and its modules: its own, else (-1) the
  // popouts'
  function paddingOf(menu) {
    return menu.padding >= 0 ? menu.padding : PopoutConfig.padding;
  }

  // The menu's length along its edge, from config alone (for the hover
  // strip before the menu has ever been loaded): its columns side by side
  // at its card size, as EdgeMenuBody lays them out, plus its padding
  function lengthOf(menu, vertical) {
    const flows = menu.columns.map(column => OverlayLayout.columnFlow(column.cells, menu.cardSize));
    return OverlayLayout.columnsLength(flows, vertical, vertical ? menu.extraHeight : menu.extraWidth) + root.paddingOf(menu) * 2;
  }
}
