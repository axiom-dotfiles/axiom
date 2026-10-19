pragma ComponentBehavior: Bound
import QtQuick
import Quickshell

import qs.components.methods

/*
 * Axiom's sway layer sent at runtime (RuntimeLayer), for SwayConfigWriter,
 * which owns it and sets readBinds: sway can't list its binds, so the
 * user's are read from their config files (SwayConfigWriter.readUserBinds).
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

  property PersistentProperties _state: PersistentProperties {
    id: persisted
    reloadableId: "axiomSwayRuntime"
    // The commands taking out what this layer bound (JSON)
    property string unbindJson: "[]"
  }

  logTag: "SwayConfigWriter"
  configName: "sway"
  canBind: bind => SwayConf.isComplete(bind, root.bindCtx)
  send: binds => {
    const unbind = JSON.parse(persisted.unbindJson);
    persisted.unbindJson = JSON.stringify(SwayConf.unbindLines(binds, root.bindCtx));
    // Sent apart, in order: sway stops a command list at an invalid
    // command, so a bind it refuses would take the look with it. Each list
    // waits for the one before, so its lines sent again alone can't
    // unbind what the next list binds.
    // Sway sends no event for a gap change: the windows are read again
    root._sendEach(unbind, () => root._sendEach(SwayConf.bindLines(binds, root.bindCtx, true), () => SwayManager.runCommands(root.lookLines(), () => SwayManager.refresh())));
  }
  takeOut: () => {
    const unbind = JSON.parse(persisted.unbindJson);
    persisted.unbindJson = "[]";
    root._sendEach(unbind);
  }
  onReloaded: persisted.unbindJson = "[]"

  // Runs `lines` as one command list; if sway refused one (an unknown key
  // ends the list there, dropping every line after it), each again alone.
  // Binding a key again is harmless (--no-warn). Then calls `then`, so what
  // it sends next goes after those.
  function _sendEach(lines, then) {
    SwayManager.runCommands(lines, ok => {
      if (!ok && lines.length > 1)
        lines.forEach(line => SwayManager.runCommands([line]));
      then?.();
    });
  }
}
