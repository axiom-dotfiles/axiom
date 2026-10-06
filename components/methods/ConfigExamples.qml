pragma Singleton
import QtQuick

// Example setups (examples/*.json): partial configs that hold only how the
// desktop looks and is laid out. Applying one replaces those parts of the
// running config and leaves the rest (wallpapers, monitors, apps,
// calendars, chat, Hyprland, idle, the greeter, …) as the user set it.
QtObject {
  id: root

  // Top-level section → true (the whole section) or the keys taken from it
  readonly property var sections: ({
      "Appearance": ["font", "motion", "shape", "theme"],
      "BarStyle": true,
      "Bars": true,
      "Dock": true,
      "EdgeMenus": true,
      "Icons": true,
      "Lockscreen": ["blurWallpaper", "layout"],
      "Notifications": ["evenGaps", "gap", "gapBottom", "gapLeft", "gapRight", "gapTop", "maxToasts", "position", "width"],
      "OSD": true,
      "Overlay": ["size", "views"],
      "Popouts": true,
      "PowerMenu": ["actions", "backdrop", "confirm", "showBackdrop", "showHeader", "showHint", "tileSize"],
      "Widget": true,
      "WindowSwitcher": ["previews", "tileSize"],
      "WorkspaceOverlay": true,
      "Workspaces": true
    })

  // The parts of `config` an example holds
  function pick(config) {
    const result = {};
    for (const section in sections) {
      if (config[section] === undefined)
        continue;
      const keys = sections[section];
      if (keys === true) {
        result[section] = JSON.parse(JSON.stringify(config[section]));
        continue;
      }
      result[section] = keys.reduce((picked, key) => {
        if (config[section][key] !== undefined)
          picked[key] = JSON.parse(JSON.stringify(config[section][key]));
        return picked;
      }, {});
    }
    return result;
  }

  // A copy of `current` with the example's parts in place of its own. Both
  // are whole configs of the same version (load the example first, so it is
  // migrated and filled). A part replaces the current one outright, so
  // nothing of the old layout (a bar, a menu) is left behind.
  function apply(current, example) {
    const result = JSON.parse(JSON.stringify(current));
    const picked = pick(example);
    for (const section in picked) {
      if (sections[section] === true || result[section] === undefined)
        result[section] = picked[section];
      else
        Object.assign(result[section], picked[section]);
    }
    return result;
  }
}
