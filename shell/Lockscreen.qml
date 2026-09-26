import QtQuick
import Quickshell
import Quickshell.Wayland

import qs.services
import qs.components.surfaces.lockscreen

// The built-in locker (Lockscreen.mode "quickshell"): a Wayland session
// lock (ext-session-lock-v1, like hyprlock). While it holds, the compositor
// shows only the lock surfaces, one per screen, and routes all input to
// them; if qs dies, the session stays locked. Locking comes from
// LockManager.lock(); the only way out is AuthManager's PAM success.
Scope {
  id: root

  // Survives QML reloads, so reloading the config while locked comes back
  // locked (a plain property would reset to false and unlock)
  PersistentProperties {
    id: lockState
    reloadableId: "axiomLockscreen"

    property bool locked: false
  }

  Connections {
    target: LockManager

    function onLockRequested() {
      if (LockManager.mode !== "quickshell" || lockState.locked)
        return;
      AuthManager.cancel();
      lockState.locked = true;
    }
  }

  Connections {
    target: AuthManager

    function onAuthenticationSucceeded() {
      lockState.locked = false;
    }
  }

  Binding {
    target: LockManager
    property: "builtinLocked"
    value: lockState.locked
  }

  WlSessionLock {
    id: sessionLock
    locked: lockState.locked

    WlSessionLockSurface {
      id: surface
      color: "black"

      LockSurface {
        screen: surface.screen
      }
    }
  }
}
