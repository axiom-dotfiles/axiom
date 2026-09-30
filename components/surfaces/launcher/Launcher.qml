pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Io

import qs.components.hosts.popout
import qs.components.reusable
import qs.config
import qs.services

// The search launcher on one screen. LauncherManager builds the rows from
// the text and runs them, LauncherPanel shows them, and this picks the
// host from Launcher.position: a FloatingPopout, or on the top or bottom
// edge an EdgePopout that grows out of the border or bar there. Both have
// the same API (show/hide/isOpen/contentItem/window), and only the one in
// use is created.
Scope {
  id: root

  required property ShellScreen screen

  readonly property var host: LauncherConfig.attached ? edgeLoader.item : floatingLoader.item
  readonly property bool shown: root.host?.isOpen ?? false
  // What the panel searches for when it's created (it only exists while
  // the host is open)
  property string _openText: ""

  function open(text) {
    root._openText = text ?? "";
    // Searched first, so instances this opens on other monitors (see
    // SurfaceGroup) show the same text
    LauncherManager.query(root._openText);
    if (!root.host)
      return;
    if (root.host.isOpen)
      root.host.contentItem?.reset(root._openText);
    else
      root.host.show();
  }

  function close() {
    root.host?.hide();
  }

  function toggle() {
    if (root.shown)
      close();
    else
      open("");
  }

  // On every monitor, the instances open and close together
  SurfaceGroup {
    id: group
    kind: "launcher"
    mode: LauncherConfig.monitors
    screen: root.screen
    window: root.host?.window ?? null
    shown: root.shown
    onSyncRequested: shown => shown ? root.open(LauncherManager.text) : root.close()
  }

  Connections {
    target: ShellManager
    enabled: ShellManager.isTarget(root.screen, LauncherConfig.monitors)
    function onToggleAppLauncher() {
      root.toggle();
    }
  }

  // Locking from anywhere closes it, so it isn't still up on unlock
  Connections {
    target: LockManager
    function onLockStarted() {
      root.close();
    }
  }

  IpcHandler {
    target: "appLauncher"
    enabled: ShellManager.isTarget(root.screen, LauncherConfig.monitors)

    function toggle(): void {
      root.toggle();
    }
    // Not "show": `qs ipc call <target> show` is taken by the CLI
    function open(): void {
      if (!root.shown)
        root.open("");
    }
    function close(): void {
      root.close();
    }
    // Opens with `text` searched, e.g. "/theme " or "="
    function search(text: string): void {
      root.open(text);
    }
  }

  // The dim background, under the bars and border, for either host
  ScreenBackdrop {
    screen: root.screen
    shown: root.shown && LauncherConfig.showBackdrop
    fillColor: Theme.background
    fillOpacity: LauncherConfig.backdrop
  }

  LazyLoader {
    id: floatingLoader
    active: !LauncherConfig.attached

    FloatingPopout {
      id: floating
      screen: root.screen
      xFraction: 0.5
      // Centred, or its top in the upper third
      yFraction: LauncherConfig.position === "center" ? 0.5 : 0.18
      yAlign: LauncherConfig.position === "center" ? 0.5 : 0
      margin: 16
      // Resized as results come and go, the box would move
      maxContentHeight: (floating.contentItem as LauncherPanel)?.maxHeight ?? 0
      // Reversed, the search field stays put at the bottom
      growUp: LauncherConfig.reverse
      contentPadding: Appearance.borderWidth
      strokeColor: Theme.border
      closedScale: 0.97
      layerNamespace: "axiom-launcher"
      wantsKeyboardFocus: true
      closeOnClickOutside: true
      grabEnabled: group.ownsGrab
      grabWindows: group.windows.filter(w => w !== floating.window)

      content: Component {
        LauncherPanel {
          // Stays open until Esc, a pick or a click elsewhere
          readonly property bool autoDismiss: false
          implicitWidth: Math.min(LauncherConfig.width, root.screen.width - 32)
          shown: floating.isOpen
          onCloseRequested: floating.hide()
          Component.onCompleted: reset(root._openText)
        }
      }
    }
  }

  LazyLoader {
    id: edgeLoader
    active: LauncherConfig.attached

    EdgePopout {
      id: popout
      screen: root.screen
      edge: LauncherConfig.position === "bottom" ? Bar.Bottom : Bar.Top
      position: 0.5
      triggerEnabled: false
      wantsKeyboardFocus: true
      closeOnClickOutside: true
      grabEnabled: group.ownsGrab
      grabWindows: group.windows.filter(w => w !== popout.window)
      // Resized as results come and go, the window would jump
      maxContentDepth: (popout.contentItem as LauncherPanel)?.maxHeight ?? 0

      content: Component {
        LauncherPanel {
          // Stays open until Esc, a pick or a click elsewhere
          readonly property bool autoDismiss: false
          implicitWidth: Math.min(LauncherConfig.width, root.screen.width - 64)
          shown: popout.isOpen
          onCloseRequested: popout.hide()
          Component.onCompleted: reset(root._openText)
        }
      }
    }
  }
}
