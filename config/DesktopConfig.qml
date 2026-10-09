pragma Singleton
import QtQuick
import qs.services
import qs.components.methods

// Reader for the Desktop section: overlay modules on the desktop, under
// the windows. A monitor shows its own layout (`monitors`, by name) if it
// has one, else the primary monitor's (`primary`, on the primary monitor),
// else the one for all monitors (`all`), each only while enabled: a
// monitor's own layout turned off leaves it empty. Each layout is a
// DesktopLayout ({ enabled, monitor, columns, rows, fineGrid,
// moduleBorders, modules }). The layouts editor's unsaved draft shows live
// (DesktopManager sets it as a preview).
QtObject {
  id: root

  readonly property var desktop: ConfigManager.previews.Desktop ?? ConfigManager.config.Desktop
  // As saved
  readonly property var savedDesktop: ConfigManager.config.Desktop
  // A DesktopLayout's own fields in groups (`x-group`), for the layouts
  // editor
  readonly property var fieldGroups: SchemaLayout.objectGroups(ConfigManager.configSchema.definitions.DesktopLayout, ["modules"])

  // The primary monitor's name, as surfaces place on it (a primary monitor
  // that isn't plugged in falls back to the first screen)
  readonly property string primaryName: General.screensNamed(General.primaryMonitor)[0]?.name ?? ""

  // Which layout the screen named `name` shows in `desktop` (a Desktop
  // section; the live one when left out): "monitor" (its own), "primary",
  // "all", or "" for none
  function sourceFor(name, desktop) {
    const section = desktop ?? root.desktop;
    const own = section.monitors.find(layout => layout.monitor === name);
    if (own)
      return own.enabled ? "monitor" : "";
    if (name === root.primaryName && section.primary.enabled)
      return "primary";
    return section.all.enabled ? "all" : "";
  }

  // The DesktopLayout the screen named `name` shows, or null
  function layoutFor(name) {
    switch (root.sourceFor(name)) {
    case "monitor":
      return root.desktop.monitors.find(layout => layout.monitor === name);
    case "primary":
      return root.desktop.primary;
    case "all":
      return root.desktop.all;
    }
    return null;
  }
}
