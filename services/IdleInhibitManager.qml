pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Shared on/off state for keeping the session awake. The Wayland idle
// inhibitor itself needs a visible surface, so it lives in the bar widget
// (bar/widgets/IdleInhibitor.qml) and binds to `enabled` here. Kept across
// QML reloads, but a restart always starts with idle allowed.
//
//   qs -c axiom ipc call idleInhibit toggle
Singleton {
  id: root

  property alias enabled: _run.enabled

  PersistentProperties {
    id: _run
    reloadableId: "axiomIdleInhibit"
    property bool enabled: false
  }

  function toggle() {
    root.enabled = !root.enabled;
  }

  property IpcHandler _ipc: IpcHandler {
    target: "idleInhibit"

    function toggle(): void {
      root.toggle();
    }

    function enable(): void {
      root.enabled = true;
    }

    function disable(): void {
      root.enabled = false;
    }

    function status(): bool {
      return root.enabled;
    }
  }
}
