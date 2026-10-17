pragma ComponentBehavior: Bound
import QtQuick
import Quickshell

import qs.components.methods

/*
 * Axiom's sway layer sent at runtime (RuntimeLayer), for SwayConfigWriter,
 * which owns it. Sway can't list its binds, so the user's are read from
 * their config files (SwayConfigWriter.readUserBinds).
 *
 * The keys this layer bound are kept (as the commands unbinding them) in a
 * PersistentProperties, so a reload of the shell takes them out before
 * binding again; a sway reload drops them itself.
 */
RuntimeLayer {
  id: root

  // What the bind commands need from outside the bind (SwayConf.command)
  property var bindCtx: ({})
  // A function returning the live lines (the look and the input)
  property var lookLines: () => []
  // A function calling back with the user's binds (SwayConf.configBinds
  // entries), or null when they couldn't be read
  property var readUserBinds: callback => callback([])

  property PersistentProperties _state: PersistentProperties {
    id: persisted
    reloadableId: "axiomSwayRuntime"
    // The commands taking out what this layer bound (JSON)
    property string unbindJson: "[]"
  }

  logTag: "SwayConfigWriter"
  configName: "sway"
  canBind: bind => SwayConf.isComplete(bind, root.bindCtx)
  readBinds: callback => root.readUserBinds(entries => callback(entries, null))
  send: binds => {
    const unbind = JSON.parse(persisted.unbindJson);
    persisted.unbindJson = JSON.stringify(SwayConf.unbindLines(binds, root.bindCtx));
    // Sent apart, in order: sway stops a command list at an invalid
    // command, so a bind it refuses would take the look with it
    for (const lines of [unbind, SwayConf.bindLines(binds, root.bindCtx, true)]) {
      if (lines.length > 0)
        SwayManager.runCommands(lines);
    }
    // Sway sends no event for a gap change: the windows are read again
    SwayManager.runCommands(root.lookLines(), () => SwayManager.refresh());
  }
  takeOut: () => {
    const unbind = JSON.parse(persisted.unbindJson);
    persisted.unbindJson = "[]";
    if (unbind.length > 0)
      SwayManager.runCommands(unbind);
  }
  onReloaded: persisted.unbindJson = "[]"
}
