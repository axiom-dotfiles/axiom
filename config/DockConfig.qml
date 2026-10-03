pragma Singleton
import QtQuick
import qs.services

// Reader for the Dock section: any number of docks, each with its own
// place, pinned apps and behaviour (DockEntry in the schema). Named
// DockConfig because `Dock` is the shell module.
QtObject {
  id: root

  readonly property var _c: ConfigManager.config.Dock

  readonly property bool enabled: _c.enabled
  // [DockEntry]. Goes through a string so a reload that leaves the list
  // unchanged doesn't rebuild the docks.
  readonly property string _docksJson: JSON.stringify(_c.docks)
  readonly property var docks: JSON.parse(_docksJson)
  // The enabled ones, by id: what the shell builds (none while the section
  // is off)
  readonly property var shownIds: root.enabled ? root.docks.filter(dock => dock.enabled).map(dock => dock.id) : []

  function dockById(id) {
    return root.docks.find(dock => dock.id === id) ?? null;
  }

  // The screens a dock may be on, by its `monitors` (as an OSD's): every
  // one for "focused" and "all" (shell/Dock shows it only where
  // ShellManager.showsOn puts it), else the one it's on
  function screensOf(dock) {
    return General.screensFor(dock.monitors, dock.monitor);
  }

  // The name on its tab: its own, else its edge's
  function labelOf(dock) {
    if (dock.name)
      return dock.name;
    const names = {
      "Top": I18n.tr("Top dock"),
      "Bottom": I18n.tr("Bottom dock"),
      "Left": I18n.tr("Left dock"),
      "Right": I18n.tr("Right dock")
    };
    return names[dock.edge] ?? dock.edge;
  }
}
