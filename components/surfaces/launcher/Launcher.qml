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
// host from Launcher.position: a floating LauncherWindow, or on the top or
// bottom edge an EdgePopout that grows out of the border or bar there.
// Only the host in use is created.
Scope {
  id: root

  required property ShellScreen screen

  readonly property bool shown: LauncherConfig.attached ? (edgeLoader.item?.isOpen ?? false) : (windowLoader.item?.shown ?? false)
  // What an edge popout's panel searches for when it's created
  property string _openText: ""

  function open(text) {
    // Searched first, so instances this opens on other monitors (see
    // SurfaceGroup) show the same text
    LauncherManager.query(text ?? "");
    if (!LauncherConfig.attached) {
      windowLoader.item?.open(text);
      return;
    }
    const popout = edgeLoader.item;
    if (!popout)
      return;
    root._openText = text ?? "";
    // Its content only exists while open
    if (popout.isOpen)
      popout.contentItem?.reset(root._openText);
    else
      popout.show();
  }

  function close() {
    windowLoader.item?.close();
    edgeLoader.item?.hide();
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
    window: LauncherConfig.attached ? (edgeLoader.item?.window ?? null) : (windowLoader.item ?? null)
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
    id: windowLoader
    active: !LauncherConfig.attached

    LauncherWindow {
      screen: root.screen
      ownsGrab: group.ownsGrab
      grabWindows: group.windows
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
