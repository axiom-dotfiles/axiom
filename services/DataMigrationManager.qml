pragma Singleton
import QtQuick
import Quickshell
import qs.components.methods
import qs.config

/* Moves an install from before the XDG folders over to them, once.
 *
 * While the repo's config/user/ still holds a config.json with no
 * DataDirs.movedMarker beside it (ConfigManager.legacyLayout), the session
 * runs on the old folders as before. This copies them into the XDG ones
 * (scripts/migrate_xdg.sh: never overwriting, config.json last, then the
 * marker) with config saves held, and reloads: the next load finds the
 * marker and runs on the XDG folders. The old folders are kept. A failed
 * copy writes no marker, so the next start tries again. */
QtObject {
  id: root

  // The last run's result: "" (none), "running", "done" or "failed"
  readonly property string status: _status
  property string _status: ""

  // [from, to, …] for the folders that move (state and data were XDG already)
  function _pairs() {
    const from = ConfigManager.legacyDirs;
    const to = ConfigManager.xdgDirs;
    return [].concat(...["config", "ui", "notes", "generatedThemes"].map(key => [from[key], to[key]]));
  }

  function _migrate() {
    const marker = ConfigManager.legacyDirs.config + DataDirs.movedMarker;
    root._status = "running";
    ConfigManager.holdSaves(true);
    console.log("[DataMigrationManager] Moving axiom's config and state out of", Paths.axiomPath, "to", ConfigManager.xdgDirs.config, "and", ConfigManager.xdgDirs.state);
    CommandManager.run([Paths.scriptsPath + "migrate_xdg.sh", marker].concat(root._pairs()), (exitCode, out, err) => {
      if (exitCode !== 0) {
        root._status = "failed";
        ConfigManager.holdSaves(false);
        console.warn("[DataMigrationManager] Could not move the config and state to the XDG folders; staying on the old ones until the next start:", (err || out).trim());
        return;
      }
      root._status = "done";
      out.trim().split("\n").forEach(line => console.log("[DataMigrationManager] Copied", line));
      Quickshell.reload(false);
    });
  }

  Component.onCompleted: if (ConfigManager.legacyLayout)
    Qt.callLater(root._migrate)
}
