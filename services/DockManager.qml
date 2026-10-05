pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland

import qs.config
import qs.components.methods

// The docks' shared state and actions (the docks themselves are
// shell/Dock): which apps a dock shows on a screen (its pinned ones, then
// running ones, windows grouped by desktop entry), what a click does
// (launch, focus, cycle), pinning (written to Dock.docks at once), whether
// a window covers a dock (intellihide), and the `dock` IPC target.
QtObject {
  id: root

  // Always-shown docks hidden by hand ({ id: true }), shared by every
  // screen's copy
  property var hidden: ({})

  // A hover dock should slide in, or out (every screen's copy of it)
  signal revealRequested(string id)
  signal concealRequested(string id)
  signal toggleRequested(string id)

  // Window class -> desktop entry id, for the classes that have one
  property var _classCache: ({})

  // An app's key: its desktop entry id, else its window class
  function appKey(win) {
    const cls = win["class"] || win.initialClass || "";
    if (!cls)
      return "";
    const cached = root._classCache[cls];
    if (cached)
      return cached;
    const entry = DesktopEntries.heuristicLookup(cls);
    if (!entry)
      return cls;
    root._classCache[cls] = entry.id;
    return entry.id;
  }

  function entryFor(key) {
    return DesktopEntries.byId(key) ?? DesktopEntries.heuristicLookup(key);
  }

  function iconFor(key, win) {
    const entry = root.entryFor(key);
    if (entry?.icon)
      return Quickshell.iconPath(entry.icon, "application-x-executable");
    return IconResolver.resolveWindowIcon(win?.["class"] ?? key, win?.title ?? "");
  }

  function nameFor(key, win) {
    return root.entryFor(key)?.name || win?.["class"] || key;
  }

  // The dock's items on a screen ([{ key, pinned, windows }], see
  // DockLayout.buildItems), windows counted by its windowScope
  function itemsFor(dock, screen) {
    if (!dock)
      return [];
    const monitor = screen ? Hyprland.monitorFor(screen) : null;
    const monitorId = monitor?.id ?? -1;
    const workspaceId = monitor?.activeWorkspace?.id ?? -1;
    const windows = HyprlandManager.windowList.filter(w => DockLayout.inScope(w, dock.windowScope, monitorId, workspaceId));
    return DockLayout.buildItems(dock.pinned, windows, w => root.appKey(w), dock.showRunning);
  }

  readonly property string focusedAddress: HyprlandManager.windowList.find(w => w.focusHistoryID === 0)?.address ?? ""

  // A click: start the app when it has no windows, else focus its most
  // recent one, or the next when one of them is focused
  function activate(item) {
    if (item.windows.length === 0)
      return root.launch(item.key);
    HyprlandManager.focusWindow(DockLayout.clickTarget(item.windows, root.focusedAddress));
  }

  function focus(address) {
    HyprlandManager.focusWindow(address);
  }

  // A new instance (middle click, the menu's New window)
  function launch(key) {
    const entry = root.entryFor(key);
    if (!entry) {
      console.warn(`[DockManager] No desktop entry for "${key}"`);
      return;
    }
    LauncherManager.launchApp(entry);
  }

  function closeWindows(item) {
    item.windows.forEach(w => HyprlandManager.closeWindow(w.address));
  }

  // --- Pinning (saved at once) ---

  function _editDock(dockId, change) {
    const docks = Utils.clone(DockConfig.docks);
    const dock = docks.find(d => d.id === dockId);
    if (!dock)
      return;
    change(dock);
    SettingsManager.commitValues({
      "Dock.docks": docks
    });
  }

  // Pins an app at `index` (the end when -1), moving it there when it's
  // already pinned
  function pin(dockId, key, index) {
    root._editDock(dockId, dock => {
      const pinned = dock.pinned.filter(k => k !== key);
      pinned.splice(index < 0 ? pinned.length : Math.min(index, pinned.length), 0, key);
      dock.pinned = pinned;
    });
  }

  function unpin(dockId, key) {
    root._editDock(dockId, dock => dock.pinned = dock.pinned.filter(k => k !== key));
  }

  // --- Reserved space ---

  // What each shown dock reserves, by "<screen>:<edge>:<dock id>" (edge
  // "top" | "bottom" | "left" | "right"): EdgePopouts (the OSD, edge
  // menus) reach past it to the border, so a dock doesn't push them in
  property var zones: ({})

  function setZone(screenName, edge, dockId, size) {
    const key = `${screenName}:${edge}:${dockId}`;
    if ((root.zones[key] ?? 0) === size)
      return;
    const zones = Object.assign({}, root.zones);
    if (size > 0)
      zones[key] = size;
    else
      delete zones[key];
    root.zones = zones;
  }

  // The space docks reserve on a screen edge, together
  function zoneOn(screenName, edge) {
    const prefix = `${screenName}:${edge}:`;
    return Object.keys(root.zones).filter(key => key.startsWith(prefix)).reduce((sum, key) => sum + root.zones[key], 0);
  }

  // --- Showing and hiding ---

  // The space reserved on each side of a screen, [left, top, right,
  // bottom]: where its work area starts (Hyprland's monitor `reserved`).
  // It arrives as a QVariantList, which isn't a JS Array (Array.isArray is
  // false), so it's copied by index.
  function reservedOf(screen) {
    const reserved = (screen ? Hyprland.monitorFor(screen) : null)?.lastIpcObject?.reserved;
    return reserved?.length === 4 ? [0, 1, 2, 3].map(i => Number(reserved[i]) || 0) : [0, 0, 0, 0];
  }

  // Quickshell only re-reads monitors on monitor events, and Hyprland
  // sends none when windows retile around a reserved zone that changed, so
  // both are re-read when a layer surface (a bar, a dock) comes or goes, or
  // a dock's zone changes (refreshSoon)
  function refreshSoon() {
    root._refresh.restart();
  }

  property Timer _refresh: Timer {
    interval: 200
    onTriggered: {
      Hyprland.refreshMonitors();
      HyprlandManager.updateAll();
    }
  }

  // Only while a dock is built: nothing else reads the refreshed state,
  // and every popout, OSD and toast opens a layer
  readonly property bool _active: DockConfig.shownIds.length > 0
  on_ActiveChanged: {
    if (root._active)
      Hyprland.refreshMonitors();
  }

  property Connections _layers: Connections {
    target: Hyprland
    enabled: root._active

    function onRawEvent(event) {
      if (event.name === "openlayer" || event.name === "closelayer" || event.name === "configreloaded")
        root.refreshSoon();
    }
  }

  // Whether a window on the screen's active workspace covers `rect`
  // (screen-local)
  function obscured(screen, rect) {
    const monitor = screen ? Hyprland.monitorFor(screen) : null;
    const workspaceId = monitor?.activeWorkspace?.id;
    if (workspaceId === undefined)
      return false;
    // An open special workspace sits over the regular one
    const specialId = HyprlandManager.specialWorkspaceId(monitor);
    const windows = HyprlandManager.windowList.filter(w => w.mapped && !w.hidden && (w.workspace?.id === workspaceId || (specialId !== 0 && w.workspace?.id === specialId)));
    return DockLayout.covered({
      "x": rect.x + screen.x,
      "y": rect.y + screen.y,
      "width": rect.width,
      "height": rect.height
    }, windows);
  }

  function _ids(id) {
    return id ? [id] : DockConfig.shownIds;
  }

  function _setHidden(id, value) {
    const next = Object.assign({}, root.hidden);
    if (value)
      next[id] = true;
    else
      delete next[id];
    root.hidden = next;
  }

  // Empty ids act on every dock
  function show(id) {
    root._ids(id).forEach(each => {
      root._setHidden(each, false);
      root.revealRequested(each);
    });
  }

  function hide(id) {
    root._ids(id).forEach(each => {
      if (DockConfig.dockById(each)?.visibility === "always")
        root._setHidden(each, true);
      else
        root.concealRequested(each);
    });
  }

  function toggle(id) {
    root._ids(id).forEach(each => {
      if (DockConfig.dockById(each)?.visibility === "always")
        root._setHidden(each, !root.hidden[each]);
      else
        root.toggleRequested(each);
    });
  }

  Component.onCompleted: {
    if (root._active)
      Hyprland.refreshMonitors();
  }

  property IpcHandler _ipc: IpcHandler {
    target: "dock"

    function toggle(id: string): void {
      root.toggle(id);
    }

    // Not `show`: qs's own `ipc show` would take the call
    function open(id: string): void {
      root.show(id);
    }

    function close(id: string): void {
      root.hide(id);
    }
  }
}
