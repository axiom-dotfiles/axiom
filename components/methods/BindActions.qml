pragma Singleton
import QtQuick

// What each keybind action (the schema's Hyprland.binds[].action) is,
// independent of the compositor: its IPC call into axiom, default label,
// section on the Keybinds page, calls, starting flags and whether it takes
// an argument. How an action is bound (Hyprland's Lua) is
// HyprConfigLua.dispatcherLua. Labels aren't translated: they go to the
// compositor, like the user's own bind descriptions.
QtObject {
  id: root

  // Actions that call axiom over IPC ({call} is the bind's call, see
  // `calls`): [IPC call, default label, section]
  readonly property var ipcActions: ({
      "launcher": ["appLauncher {call}", "App launcher", "Axiom"],
      "launcherSearch": ["appLauncher search {0}", "Launcher: {0}", "Axiom"],
      "overlay": ["overlay {call}", "Overlay", "Axiom"],
      "overlayPage": ["overlay page {0}", "Overlay: {0}", "Axiom"],
      "edgeMenu": ["edgeMenu {call} {0}", "Edge menu: {0}", "Axiom"],
      "dock": ["dock {call} {0}", "Dock: {0}", "Axiom"],
      "workspaceOverview": ["workspaceOverlay {call}", "Workspace overview", "Workspace"],
      "powerMenu": ["powermenu {call}", "Power menu", "Axiom"],
      "lock": ["lockscreen lock", "Lock", "Axiom"],
      "toggleDnd": ["notifications toggleDnd", "Do not disturb", "Axiom"],
      "clearNotifications": ["notifications clear", "Clear notifications", "Axiom"],
      "idleInhibit": ["idleInhibit {call}", "Caffeine", "Axiom"],
      "nightLight": ["nightLight {call}", "Night light", "Axiom"],
      "nextWallpaper": ["wallpaper next", "Next wallpaper", "Axiom"],
      "workspaceStep": ["workspaces step {0} go", "Switch {0}", "Workspace"],
      "moveWindowStep": ["workspaces step {0} move", "Move window {0}", "Workspace"],
      "workspaceNth": ["workspaces nth {0} go", "Go to workspace {0}", "Workspace"],
      "moveWindowStepSilent": ["workspaces step {0} moveSilent", "Send window {0}", "Workspace"],
      "moveWindowNth": ["workspaces nth {0} move", "Move window to workspace {0}", "Workspace"],
      "moveWindowNthSilent": ["workspaces nth {0} moveSilent", "Send window to workspace {0}", "Workspace"],
      "volumeUp": ["audio volumeUp", "Volume up", "Media"],
      "volumeDown": ["audio volumeDown", "Volume down", "Media"],
      "toggleMute": ["audio toggleMute", "Mute", "Media"],
      "toggleMicMute": ["audio toggleMicMute", "Mute microphone", "Media"],
      "brightnessUp": ["brightness up", "Brightness up", "Media"],
      "brightnessDown": ["brightness down", "Brightness down", "Media"],
      "mediaPlayPause": ["media playPause", "Play/Pause", "Media"],
      "mediaNext": ["media next", "Next track", "Media"],
      "mediaPrevious": ["media previous", "Previous track", "Media"],
      "mediaStop": ["media stop", "Stop", "Media"],
      "screenshot": ["screenshot take {0}", "Screenshot: {0}", "Apps"],
      "screenRecord": ["screenRecord {call}", "Screen recording", "Apps"]
    })

  // Actions the compositor carries out itself (HyprConfigLua.dispatcherLua
  // has each one's Lua): [default label, section]
  readonly property var compositorActions: ({
      "focusDir": ["Focus {0}", "Window"],
      "moveWindowDir": ["Move {0}", "Window"],
      "resizeWindow": ["Resize by {0}", "Window"],
      "closeWindow": ["Close", "Window"],
      "fullscreen": ["Fullscreen", "Window"],
      "toggleFloat": ["Toggle floating", "Window"],
      "pin": ["Pin", "Window"],
      "centerWindow": ["Center", "Window"],
      "toggleGroup": ["Toggle group", "Window"],
      "pseudo": ["Pseudotile", "Window"],
      "toggleSplit": ["Toggle split", "Window"],
      "stripSwapColumn": ["Swap column {0}", "Window"],
      "stripWider": ["Widen column", "Window"],
      "stripNarrower": ["Narrow column", "Window"],
      "stripFit": ["Fit visible columns", "Window"],
      "lua": ["{0}", "Custom"],
      "windowSwitcher": ["Switch windows", "Window"],
      "windowSwitcherReverse": ["Switch windows backwards", "Window"],
      "mouseDrag": ["Drag", "Window"],
      "mouseResize": ["Resize", "Window"],
      "toggleSpecial": ["Toggle {0}", "Special"],
      "moveToSpecial": ["Move window to {0}", "Special"],
      "restartShell": ["Restart shell", "Axiom"],
      "exitHyprland": ["Exit Hyprland", "Axiom"],
      "terminal": ["Terminal", "Apps"],
      "fileManager": ["File manager", "Apps"],
      "browser": ["Browser", "Apps"]
    })

  // The IPC function behind each call ({call} above) for actions that open
  // and close something; a toggle is always `toggle`
  readonly property var calls: ({
      "launcher": {
        "open": "open",
        "close": "close"
      },
      "overlay": {
        "open": "open",
        "close": "close"
      },
      "edgeMenu": {
        "open": "open",
        "close": "close"
      },
      "dock": {
        "open": "open",
        "close": "close"
      },
      "powerMenu": {
        "open": "open",
        "close": "close"
      },
      "workspaceOverview": {
        "open": "show",
        "close": "hide"
      },
      "idleInhibit": {
        "open": "enable",
        "close": "disable"
      },
      "nightLight": {
        "open": "enable",
        "close": "disable"
      },
      "screenRecord": {
        "open": "enable",
        "close": "disable"
      }
    })

  // Flags an action starts with when it's picked (the bind can change them)
  readonly property var actionFlags: ({
      "resizeWindow": ["repeating"],
      "restartShell": ["release"],
      "exitHyprland": ["release"],
      "volumeUp": ["locked", "repeating"],
      "volumeDown": ["locked", "repeating"],
      "toggleMute": ["locked"],
      "toggleMicMute": ["locked"],
      "brightnessUp": ["locked", "repeating"],
      "brightnessDown": ["locked", "repeating"],
      "mediaPlayPause": ["locked"],
      "mediaNext": ["locked"],
      "mediaPrevious": ["locked"],
      "mediaStop": ["locked"]
    })
  // The flags a bind can set (bind[flag] === true)
  // reads: Hyprland.binds[].repeating, Hyprland.binds[].locked, Hyprland.binds[].release (by flag name)
  readonly property var flagNames: ["repeating", "locked", "release"]

  // The window switcher's actions, by the step each takes through the
  // windows (also how a bind is known to be one)
  readonly property var switcherSteps: ({
      "windowSwitcher": 1,
      "windowSwitcherReverse": -1
    })

  // Whether an action takes a call (toggle, open or close)
  function hasCalls(action) {
    return root.calls[action] !== undefined;
  }

  // A bind's call ({ action, call }): "toggle" unless its action has the
  // one it names
  function callOf(bind) {
    return root.calls[bind.action]?.[bind.call] !== undefined ? bind.call : "toggle";
  }

  // The IPC function a bind's call runs ("toggle", or the action's own
  // name for open/close, e.g. "show")
  function callFunction(bind) {
    return root.calls[bind.action]?.[root.callOf(bind)] ?? "toggle";
  }

  // What an action's argument is (the Keybinds page picks its editor and
  // choices by it); actions without one aren't listed. Every action with a
  // {0} in its IPC call or label is (tst_BindActions checks).
  readonly property var argumentKinds: ({
      "launcherSearch": "text",
      "exec": "text",
      "lua": "lua",
      "overlayPage": "view",
      "edgeMenu": "edgeMenu",
      "dock": "dock",
      "workspaceStep": "direction",
      "moveWindowStep": "direction",
      "moveWindowStepSilent": "direction",
      "workspaceNth": "workspace",
      "moveWindowNth": "workspace",
      "moveWindowNthSilent": "workspace",
      "focusDir": "direction",
      "moveWindowDir": "direction",
      "stripSwapColumn": "direction",
      "resizeWindow": "resize",
      "toggleSpecial": "special",
      "moveToSpecial": "special",
      "screenshot": "screenshot"
    })

  // The argument an action starts with when picked (else empty)
  readonly property var argumentDefaults: ({
      "screenshot": "region",
      "dock": "main"
    })

  // What `action`'s argument is (argumentKinds), or ""
  function argumentKind(action) {
    return root.argumentKinds[action] ?? "";
  }

  // Whether `action` needs an argument to be bound
  function needsArgument(action) {
    return root.argumentKinds[action] !== undefined;
  }

  // The section a bind's action files it under on the Keybinds page
  function sectionFor(action) {
    return root.ipcActions[action]?.[2] ?? root.compositorActions[action]?.[1] ?? "Axiom";
  }

  // The label a bind ({ action, argument, call }) gets when its
  // description is empty: `exec` shows its command, a call other than
  // toggle is added in brackets
  function defaultLabel(bind) {
    const argument = String(bind.argument ?? "").trim();
    if (bind.action === "exec")
      return argument;
    const label = (root.ipcActions[bind.action]?.[1] ?? root.compositorActions[bind.action]?.[0] ?? "").replace("{0}", argument);
    const call = root.callOf(bind);
    return call === "toggle" ? label : `${label} (${call})`;
  }

  // Whether a description names its own section ("Section: Label")
  function hasOwnSection(description) {
    return /^[^:]+: \S/.test(String(description ?? "").trim());
  }

  // The description the compositor gets for a bind: "Section: Label", the
  // section from the action unless the description names its own
  function descriptionFor(bind) {
    const own = String(bind.description ?? "").trim();
    return root.hasOwnSection(own) ? own : root.sectionFor(bind.action) + ": " + (own || root.defaultLabel(bind));
  }
}
