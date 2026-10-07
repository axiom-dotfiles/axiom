pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Hyprland

import qs.config
import qs.components.methods

/* Shell manager manages global options and signals */
QtObject {
  signal openPowerMenu
  signal toggleAppLauncher
  signal toggleOverlay
  signal toggleWorkspaceOverlay
  // Switch the overlay to a page by view type or a view's name ("Themes" and
  // "Layouts" for the pinned page), e.g. from a settings link
  signal showOverlayPage(string type)
  // Opens the target overlay on a page (a view type, or a view's name)
  signal openOverlayPage(string type)
  // Closes the overlay wherever it's open
  signal closeOverlay
  // Opens an OSD by id where it would open for a change (the settings
  // page's Show button)
  signal showOsd(string id)

  // A surface's `monitors` mode with "general" resolved: "primary" |
  // "focused" | "all"
  function modeFor(mode) {
    return !mode || mode === "general" ? General.monitors : mode;
  }

  // The screen whose instance of a surface answers a shortcut or IPC call
  // and holds the keyboard: the focused monitor when it opens there or
  // everywhere, else the one it's built on (`name` for a "monitor" mode)
  function targetFor(mode, name) {
    const resolved = modeFor(mode);
    if (resolved === "focused" || resolved === "all")
      return Hyprland.focusedMonitor?.name ?? General.primaryMonitor;
    return General.screensFor(resolved, name)[0]?.name ?? "";
  }

  function isTarget(screen, mode, name) {
    return !!screen && screen.name === targetFor(mode, name);
  }

  // Opens on every monitor at once (SurfaceGroup keeps the instances in step)
  function everywhere(mode) {
    return modeFor(mode) === "all";
  }

  // Whether a surface opened for its target also shows on `screen`
  function showsOn(screen, mode, name) {
    return !!screen && (everywhere(mode) || isTarget(screen, mode, name));
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

  // Whether one is up on `screen` (a ShellScreen or its name)
  function surfaceOpenOn(kind, screen) {
    const name = typeof screen === "string" ? screen : screen?.name ?? "";
    return openSurfaces.some(e => e.kind === kind && (e.group.screen?.name ?? "") === name);
  }

  // Surfaces sharing a screen edge give way by rank, lowest first: a dock
  // to an OSD, both to a floating edge menu (opened by hand, the pointer
  // on it). A lower one closes while a higher one shows on its edge.
  readonly property var edgeRanks: ["dock", "osd", "menu"]
  // `{ owner, screen, edge, kind }` (a screen name, a Bar.edgeName): the
  // ranked surfaces showing
  property var edgeClaims: []

  // `claim` is `{ screen, edge, kind }`, or null to release the owner's
  function setEdgeClaim(owner, claim) {
    const others = edgeClaims.filter(c => c.owner !== owner);
    if (claim)
      edgeClaims = others.concat([Object.assign({
          owner
        }, claim)]);
    else if (others.length !== edgeClaims.length)
      edgeClaims = others;
  }

  // Whether something ranked above `kind` shows on that screen edge
  function edgeOutranked(screenName, edge, kind) {
    const rank = edgeRanks.indexOf(kind);
    return edgeClaims.some(c => c.screen === screenName && c.edge === edge && edgeRanks.indexOf(c.kind) > rank);
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

  // The screenshot pickers while one is open: every focus grab lets input
  // through to them, so taking a screenshot closes nothing
  property var captureWindows: []
  // Every picker's frame is frozen: popup windows (bar popouts, tooltips,
  // menus, toasts) hide until it closes, since Hyprland draws popups over
  // every layer. The frame already holds them, so nothing seems to change.
  readonly property bool captureFrozen: captureWindows.length > 0 && captureWindows.every(w => w.frozen)

  // --- Screen layouts' required fields ---

  // Which screen layout surfaces (the lock screen's, the greeter's, by the
  // key their host gives their modules) show their required field: the
  // Password module, the Login module. A surface without one shows a
  // fallback field of its own, so a broken layout can never lock anyone
  // out, or in
  readonly property var requiredFields: _requiredFields
  property var _requiredFields: ({})

  // A key for one surface, never reused: a screen that drops out and comes
  // back (a monitor turned off) gets a new surface while the old one is
  // still being torn down, and a key shared by screen name let the old
  // module's goodbye clear the new one's report, flickering in the
  // fallback field. `kind` names it ("lock", "preview", "greeter")
  property int _surfaceCount: 0
  function newSurfaceKey(kind) {
    _surfaceCount += 1;
    return kind + ":" + _surfaceCount;
  }

  function reportRequiredField(key, present) {
    if (!key || (_requiredFields[key] === true) === present)
      return;
    _requiredFields = Utils.withEntry(_requiredFields, key, present ? true : undefined);
  }

  // Windows every focus grab lets input through to: the screenshot
  // pickers and modal prompts (the polkit prompt, registerModal), so one
  // opening over the overlay or a popout closes nothing
  readonly property var modalWindows: captureWindows.concat(_modals)
  property var _modals: []

  function registerModal(window) {
    _modals = _modals.filter(w => w !== window).concat([window]);
  }

  function unregisterModal(window) {
    _modals = _modals.filter(w => w !== window);
  }

  // Set while a prompt axiom doesn't draw needs the screen (another polkit
  // agent's window, the file picker: windows open under axiom's
  // Overlay-layer surfaces): the overlay and the onboarder hide without
  // closing, keeping their page and state, and come back when every owner
  // has ended it
  readonly property bool steppedAside: _stepAsideOwners.length > 0
  property var _stepAsideOwners: []

  function beginStepAside(owner) {
    if (!_stepAsideOwners.includes(owner))
      _stepAsideOwners = _stepAsideOwners.concat([owner]);
  }

  function endStepAside(owner) {
    _stepAsideOwners = _stepAsideOwners.filter(o => o !== owner);
  }

  // The bar windows (BarPanel), for surfaces that attach to a bar without
  // being its popouts (floating edge menus)
  property var barPanels: []

  function registerBar(panel) {
    barPanels = barPanels.filter(p => p !== panel).concat([panel]);
  }

  function unregisterBar(panel) {
    barPanels = barPanels.filter(p => p !== panel);
  }

  // The enabled bar on a screen edge (a Bar.Location), or null
  function barOn(screenName, location) {
    return barPanels.find(p => p.barConfig.enabled && p.barConfig.location === location && p.screen?.name === screenName) ?? null;
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
