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
  // A menu's own fields in groups (`x-group`), for the edge menu editor
  readonly property var fieldGroups: SchemaLayout.objectGroups(ConfigManager.configSchema.definitions.EdgeMenu, ["modules"])

  function menuById(id) {
    return root.menus.find(menu => menu.id === id) ?? null;
  }

  // The first enabled menu holding a module of `type`, else null
  function menuWithModule(type) {
    return root.enabledMenus.find(menu => menu.modules.some(module => module.type === type)) ?? null;
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
  // strip before the menu has ever been loaded): its modules' grid at
  // card size `unit` (EdgeMenuManager.cardUnitOf), as EdgeMenuBody lays
  // it out, plus its padding
  function lengthOf(menu, vertical, unit) {
    const sizes = GridPlacement.trackSizes(GridPlacement.bounds(menu.modules), unit);
    return (vertical ? sizes.height : sizes.width) + root.paddingOf(menu) * 2;
  }
}
