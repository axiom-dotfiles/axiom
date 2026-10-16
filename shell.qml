//@ pragma UseQApplication
//@ pragma Env QS_NO_RELOAD_POPUP=1
//@ pragma Env QSG_RENDER_LOOP=threaded
//@ pragma Env QT_QUICK_FLICKABLE_WHEEL_DECELERATION=10000
//@ pragma Env mesa_glthread=false

pragma ComponentBehavior: Bound
import Quickshell
import Quickshell.Io // TEMP
import qs.components.methods // TEMP
import qs.config // TEMP
import qs.services
import qs.shell

// The shell's entrypoint: one top-level piece per surface (shell/), plus
// _services, which creates the services nothing else would reference.
ShellRoot {
  IpcHandler { // TEMP
    target: "bindsTmp"
    function fix(): string {
      const repeats = action => (BindActions.actionFlags[action] ?? []).includes("repeating") || action === "raw";
      const changed = [];
      const binds = KeybindsConfig.binds.map(bind => {
        if (!bind.repeating || repeats(bind.action))
          return bind;
        changed.push(bind.key);
        return Object.assign({}, bind, { "repeating": false });
      });
      if (changed.length === 0)
        return "nothing to change";
      return (SettingsManager.commitValues({ "Keybinds.binds": binds }) ? "saved: " : "REJECTED: ") + changed.join(", ");
    }
  }
  id: shellRoot

  // Services with no UI of their own, which nothing else would create
  // (CompositorConfigManager only with configModes, where it has work at
  // start; elsewhere other services may still create it, and it stays
  // inert: live)
  readonly property var _services: [DataMigrationManager, DependencyManager, CompositorManager, CompositorManager.supports.configModes ? CompositorConfigManager : null, HypridleManager, SelfUpdateManager, ChatManager, AudioManager, MediaManager, EdgeMenuManager, BrightnessManager, NotesManager, MonitorManager, OnboardingManager, ClipboardManager, NightLightManager, WallpaperManager, DockManager, SystemManager, BatteryManager, PolkitManager, GreeterManager, CalendarManager]

  Lockscreen {
    id: lockscreen
  }

  Notifications {
    id: notificationPopup
  }

  Overlay {
    id: overlay
  }

  Bar {
    id: mainBar
  }

  WorkspaceOverlay {
    id: workspaceOverlay
  }

  WindowSwitcher {
    id: windowSwitcher
  }

  Wallpaper {
    id: wallpaper
  }

  Desktop {
    id: desktop
  }

  Screenshot {
    id: screenshot
  }

  ScreenBorder {
    id: screenBorder
  }

  Backdrops {
    id: backdrops
  }

  BlurBacking {
    id: blurBacking
  }

  OSD {
    id: osd
  }

  AppLauncher {
    id: appLauncher
  }

  PowerMenu {
    id: powerMenu
  }

  EdgeMenus {
    id: edgeMenus
  }

  Dock {
    id: dock
  }

  MonitorPrompt {
    id: monitorPrompt
  }

  Onboarding {
    id: onboarding
  }

  IdleInhibit {
    id: idleInhibit
  }

  PolkitPrompt {
    id: polkitPrompt
  }

  GreeterPreview {
    id: greeterPreview
  }
}
