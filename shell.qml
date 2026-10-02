//@ pragma UseQApplication
//@ pragma Env QS_NO_RELOAD_POPUP=1
//@ pragma Env QSG_RENDER_LOOP=threaded
//@ pragma Env QT_QUICK_FLICKABLE_WHEEL_DECELERATION=10000

pragma ComponentBehavior: Bound
import Quickshell
import qs.services
import qs.shell

ShellRoot {
  id: shellRoot

  // Services with no UI of their own, which nothing else would create
  readonly property var _services: [DependencyManager, HyprlandConfigManager, HypridleManager, SelfUpdateManager, ChatManager, AudioManager, MediaManager, EdgeMenuManager, BrightnessManager, NotesManager, MonitorManager, OnboardingManager, ClipboardManager, NightLightManager, WallpaperManager, DockManager, SystemManager, BatteryManager]

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

  Screenshot {
    id: screenshot
  }

  ScreenBorder {
    id: screenBorder
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
}
