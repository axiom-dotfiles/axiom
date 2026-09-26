pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Hyprland

import qs.config

/* Shell manager manages global options and signals */
QtObject {
  signal openPowerMenu
  signal toggleAppLauncher
  signal toggleOverlay
  signal toggleWorkspaceOverlay
  // Switch the overlay to a page by view type or a view's name ("Themes" and
  // "OverlayEditor" for the pinned page), e.g. from a settings link
  signal showOverlayPage(string type)
  // Opens the target overlay on a page (a view type, or a view's name)
  signal openOverlayPage(string type)
  // Closes the overlay wherever it's open (e.g. to take a screenshot)
  signal closeOverlay

  // A surface's `monitors` mode with "general" resolved: "primary" |
  // "primaryBar" | "focused" | "all" (no mode is General's)
  function modeFor(mode) {
    return !mode || mode === "general" ? General.monitors : mode;
  }

  // The screen whose instance of a surface answers a shortcut or IPC call
  // and holds the keyboard: the focused monitor when it opens there or
  // everywhere, else the one it's built on
  function targetFor(mode) {
    const resolved = modeFor(mode);
    if (resolved === "primaryBar")
      return Bar.primaryMonitor;
    if (resolved === "focused" || resolved === "all")
      return Hyprland.focusedMonitor?.name ?? General.primaryMonitor;
    return General.screens[0]?.name ?? "";
  }

  // targetFor with General's mode
  readonly property string targetScreen: targetFor("general")

  function isTarget(screen, mode) {
    return !!screen && screen.name === targetFor(mode);
  }

  // Opens on every monitor at once (SurfaceGroup keeps the instances in step)
  function everywhere(mode) {
    return modeFor(mode) === "all";
  }

  // Whether a surface opened for its target also shows on `screen`
  function showsOn(screen, mode) {
    return !!screen && (everywhere(mode) || isTarget(screen, mode));
  }

  // Surfaces on every monitor at once act as one: each SurfaceGroup
  // reports its instance opening or closing, and the others follow
  signal surfaceShown(string kind, bool shown)

  // `{ group, kind, window }`: each instance's window, which the one holding
  // the focus grab lets input through to
  property var surfaceWindows: []

  function registerSurfaceWindow(group, kind, window) {
    const others = surfaceWindows.filter(e => e.group !== group);
    surfaceWindows = window ? others.concat([
      {
        group,
        kind,
        window
      }
    ]) : others;
  }

  function unregisterSurfaceWindow(group) {
    surfaceWindows = surfaceWindows.filter(e => e.group !== group);
    setSurfaceOpen(group, "", false);
  }

  // SurfaceGroups open anywhere, `{ group, kind }`: whether a launcher,
  // overlay or power menu is up (a hover-activated button won't close it)
  property var openSurfaces: []

  function setSurfaceOpen(group, kind, open) {
    const others = openSurfaces.filter(e => e.group !== group);
    if (open)
      openSurfaces = others.concat([
        {
          group,
          kind
        }
      ]);
    else if (others.length !== openSurfaces.length)
      openSurfaces = others;
  }

  function surfaceOpen(kind) {
    return openSurfaces.some(e => e.kind === kind);
  }

  // Windows a full-screen surface's focus grab lets input through to on
  // their screen: the bars and their popouts, so they stay usable while the
  // overlay is open. `{ window, screen }` (a screen name)
  property var grabPartners: []

  function registerGrabPartner(window, screenName) {
    grabPartners = grabPartners.filter(p => p.window !== window).concat([
      {
        window,
        screen: screenName ?? ""
      }
    ]);
  }

  function unregisterGrabPartner(window) {
    grabPartners = grabPartners.filter(p => p.window !== window);
  }

  // Every screen's with no screen given
  function grabPartnersFor(screen) {
    return grabPartners.filter(p => !screen || p.screen === screen.name).map(p => p.window);
  }

  // Session actions, shared by the power menu and the QuickActions
  // module. The destructive ones ask for a second click first.
  readonly property var destructiveActions: ["logout", "reboot", "poweroff"]

  // A session action's icon and label, the same everywhere it's offered
  function sessionActionInfo(action) {
    switch (action) {
    case "lock":
      return {
        icon: "lock",
        label: I18n.tr("Lock")
      };
    case "suspend":
      return {
        icon: "bedtime",
        label: I18n.tr("Suspend")
      };
    case "hibernate":
      return {
        icon: "ac_unit",
        label: I18n.tr("Hibernate")
      };
    case "logout":
      return {
        icon: "logout",
        label: I18n.tr("Log out")
      };
    case "reboot":
      return {
        icon: "restart_alt",
        label: I18n.tr("Reboot")
      };
    case "poweroff":
      return {
        icon: "power_settings_new",
        label: I18n.tr("Power off")
      };
    }
    return null;
  }

  function sessionAction(action) {
    switch (action) {
    case "lock":
      LockManager.lock();
      break;
    case "suspend":
      Quickshell.execDetached(["systemctl", "suspend"]);
      break;
    case "hibernate":
      Quickshell.execDetached(["systemctl", "hibernate"]);
      break;
    case "logout":
      Hyprland.dispatch("hl.dsp.exit()");
      break;
    case "reboot":
      Quickshell.execDetached(["systemctl", "reboot"]);
      break;
    case "poweroff":
      Quickshell.execDetached(["systemctl", "poweroff"]);
      break;
    default:
      console.warn("[ShellManager] Unknown session action:", action);
    }
  }
}
