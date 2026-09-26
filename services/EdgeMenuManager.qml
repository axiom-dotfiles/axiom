pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

import qs.config

// Which edge menus (EdgeMenusConfig) are open and which are pinned. The
// menus themselves (shell/EdgeMenus) follow this and report back when they
// close on their own. Kept across QML reloads, so a reload doesn't close an
// integrated menu and reflow the windows.
//
//   qs -c axiom ipc call edgeMenu toggle <id>
Singleton {
  id: root

  // { id: true } for each open / pinned menu
  readonly property var openMenus: root._parse(_run.open)
  readonly property var pinnedMenus: root._parse(_run.pinned)

  // What opened each menu (a bar button), which keeps a floating menu open
  // while hovered, as a bar popout's anchor does. Not kept across reloads.
  property var anchors: ({})

  // Space open integrated menus reserve, by "<screen>:<edge>" (edge
  // "top" | "bottom" | "left" | "right"), for surfaces that place
  // themselves against the perpendicular edges (BarPopouts)
  property var zones: ({})

  function setZone(screenName, edge, size) {
    const key = `${screenName}:${edge}`;
    if ((root.zones[key] ?? 0) === size)
      return;
    const zones = Object.assign({}, root.zones);
    if (size > 0)
      zones[key] = size;
    else
      delete zones[key];
    root.zones = zones;
  }

  function zoneOn(screenName, edge) {
    return root.zones[`${screenName}:${edge}`] ?? 0;
  }

  PersistentProperties {
    id: _run
    reloadableId: "axiomEdgeMenus"
    // JSON lists of ids
    property string open: "[]"
    property string pinned: "[]"
  }

  function _parse(json) {
    try {
      return JSON.parse(json).reduce((map, id) => {
        map[id] = true;
        return map;
      }, {});
    } catch (e) {
      return {};
    }
  }

  function _set(map, id, on) {
    const ids = Object.keys(map).filter(key => key !== id);
    if (on)
      ids.push(id);
    return JSON.stringify(ids);
  }

  function isOpen(id) {
    return root.openMenus[id] === true;
  }
  function isPinned(id) {
    return root.pinnedMenus[id] === true;
  }

  function open(id, anchor) {
    if (!EdgeMenusConfig.menuById(id)) {
      console.warn("No edge menu with id", id);
      return;
    }
    const anchors = Object.assign({}, root.anchors);
    anchors[id] = anchor ?? null;
    root.anchors = anchors;
    _run.open = root._set(root.openMenus, id, true);
  }

  function close(id) {
    if (!root.isOpen(id))
      return;
    _run.open = root._set(root.openMenus, id, false);
  }

  function toggle(id, anchor) {
    if (root.isOpen(id))
      root.close(id);
    else
      root.open(id, anchor);
  }

  function setPinned(id, pinned) {
    _run.pinned = root._set(root.pinnedMenus, id, pinned);
  }

  function togglePinned(id) {
    root.setPinned(id, !root.isPinned(id));
  }

  property IpcHandler _ipc: IpcHandler {
    target: "edgeMenu"

    function open(id: string): void {
      root.open(id, null);
    }

    function close(id: string): void {
      root.close(id);
    }

    function toggle(id: string): void {
      root.toggle(id, null);
    }

    function pin(id: string): void {
      root.setPinned(id, true);
    }

    function unpin(id: string): void {
      root.setPinned(id, false);
    }

    function list(): string {
      return EdgeMenusConfig.menus.map(menu => `${menu.id}${root.isOpen(menu.id) ? " (open)" : ""}${root.isPinned(menu.id) ? " (pinned)" : ""}`).join("\n");
    }
  }
}
