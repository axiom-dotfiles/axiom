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

  // A menu with no edge of its own: it opens only beside another, from a
  // Submenu module there (content/parts/MenuSubmenu)
  function isSubmenu(menu) {
    return menu?.mode === "submenu";
  }

  function menuById(id) {
    return root.menus.find(menu => menu.id === id) ?? null;
  }

  // The menu a bar widget opens as its popout (its `popoutMenu`, with
  // `showPopout` on), else "": it opens its own popout, if any. A menu
  // that's gone or disabled leaves it its own. Widgets without the fields
  // (Button, Separator, the tray) have none.
  function popoutMenuOf(properties) {
    const id = properties?.showPopout ? (properties.popoutMenu ?? "") : "";
    return id !== "" && root.enabledMenus.some(menu => menu.id === id && !root.isSubmenu(menu)) ? id : "";
  }

  // The id of the menu a bar widget entry opens, as configured (a Button
  // toggling one, or a menu popout; gone or disabled alike), else ""
  function menuOpenedBy(widget) {
    const props = widget?.properties;
    if (widget?.type === "Button")
      return props?.action === "edgeMenu" ? (props.menu ?? "") : "";
    return props?.showPopout ? (props.popoutMenu ?? "") : "";
  }

  // A bar widget with a popout of its own opens it: on, and no menu
  // opened in its place
  function opensOwnPopout(properties) {
    return !!properties?.showPopout && root.popoutMenuOf(properties) === "";
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
    return root.gridLengthOf(menu, vertical, unit) + root.paddingOf(menu) * 2;
  }

  // The menu's modules' grid along its edge, unstretched, at card size
  // `unit`
  function gridLengthOf(menu, vertical, unit) {
    const sizes = GridPlacement.trackSizes(GridPlacement.bounds(menu.modules), unit);
    return vertical ? sizes.height : sizes.width;
  }
}
