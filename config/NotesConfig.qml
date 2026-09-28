pragma Singleton
import QtQuick
import qs.services

// Reader for the Notes section (see NotesManager).
QtObject {
  id: root

  readonly property var _c: ConfigManager.config.Notes

  // Inside axiom, gitignored with the rest of config/state
  readonly property string defaultDirectory: Paths.statePath + "notes/"
  readonly property bool linked: _c.directory.trim() !== ""
  // The notes folder, absolute with a trailing slash
  readonly property string directory: {
    let dir = _c.directory.trim();
    if (dir === "")
      return root.defaultDirectory;
    if (dir === "~" || dir.startsWith("~/"))
      dir = Paths.homeDirectory + dir.slice(2);
    return dir.replace(/\/*$/, "/");
  }
  // Without dots, lower case
  readonly property var extensions: _c.extensions.map(ext => ext.trim().replace(/^\.+/, "").toLowerCase()).filter(ext => ext !== "")
  readonly property bool showHidden: _c.showHidden
  readonly property bool confirmDelete: _c.confirmDelete
}
