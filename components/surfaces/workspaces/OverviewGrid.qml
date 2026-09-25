pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Hyprland

import qs.services
import qs.config
import qs.components.methods

// One monitor's workspace board (laid out by WorkspacesConfig): wallpaper
// cells with their windows as live previews. Input is all OverviewInput's; this lays out, and turns its
// drops and resizes into HyprlandManager actions.
Rectangle {
  id: root

  required property var screen
  // Open: previews capture only then
  property bool active: true
  property real availableWidth: 1920
  property real availableHeight: 1080

  signal closeRequested

  readonly property HyprlandMonitor monitor: Hyprland.monitorFor(root.screen)
  // The workspaces shown, one per cell, and the board's shape
  readonly property var ids: HyprlandManager.workspaceIds(root.monitor)
  readonly property int columns: WorkspacesConfig.boardColumns
  readonly property int rows: WorkspacesConfig.boardRows
  readonly property int activeId: root.monitor?.activeWorkspace?.id ?? -1
  // Global layout origin (hyprctl coordinates) and logical size
  readonly property real monitorX: root.monitor?.x ?? 0
  readonly property real monitorY: root.monitor?.y ?? 0
  readonly property real monitorW: root.screen?.width ?? 1920
  readonly property real monitorH: root.screen?.height ?? 1080

  readonly property real gap: Widget.spacing * 1.5
  readonly property real pad: Widget.spacing * 2
  readonly property real miniScale: WorkspaceGeometry.fitScale(availableWidth - pad * 2, availableHeight - pad * 2, monitorW, monitorH, gap, columns, rows)
  readonly property real cellW: Math.floor(monitorW * miniScale)
  readonly property real cellH: Math.floor(monitorH * miniScale)
  readonly property real cellRadius: Math.max(2, Appearance.borderRadius * 0.75)

  // The windows on the board's workspaces: this monitor's in a grid; in the
  // standard layout workspaces are shared, so any monitor's
  readonly property var windows: HyprlandManager.windowList.filter(w => (!WorkspacesConfig.grid || w.monitor === root.monitor?.id) && root.ids.includes(w.workspace?.id) && w.mapped !== false && !w.hidden)
  readonly property var byAddress: root.windows.reduce((map, w) => {
    map[w.address] = w;
    return map;
  }, {})
  // Hit-testing and layout: [{ address, floating, cell, rect (board coords) }]
  readonly property var items: root.windows.map(w => {
    const cell = root.ids.indexOf(w.workspace.id);
    const origin = WorkspaceGeometry.cellRect(cell, root.cellW, root.cellH, root.gap, root.columns);
    const at = root.originOf(w.monitor);
    const r = WorkspaceGeometry.windowRect(w, at.x, at.y, root.miniScale, root.cellW, root.cellH);
    return {
      address: w.address,
      floating: w.floating,
      cell: cell,
      rect: {
        x: origin.x + r.x,
        y: origin.y + r.y,
        w: r.w,
        h: r.h
      }
    };
  })
  // The previews are modelled by this (through a ScriptModel, which diffs
  // it), so a window event rebuilds nothing, and a window coming or going
  // adds or removes only its own preview (and capture)
  readonly property string _addressKey: root.windows.map(w => w.address).join(",")

  // A monitor's global layout origin, by hyprctl id (this one's if unknown)
  function originOf(monitorId) {
    const m = Hyprland.monitors.values.find(m => m.id === monitorId);
    return m ? {
      x: m.x,
      y: m.y
    } : {
      x: root.monitorX,
      y: root.monitorY
    };
  }

  // The origin of the monitor a workspace is on (this one if it doesn't
  // exist yet: it opens here)
  function workspaceOrigin(workspaceId) {
    const ws = Hyprland.workspaces.values.find(ws => ws.id === workspaceId);
    return root.originOf(ws?.monitor?.id ?? root.monitor?.id);
  }

  function itemFor(address) {
    return root.items.find(item => item.address === address) ?? null;
  }

  // Set on each action: a drop can move keyboard focus, which clears the
  // focus grab, and that shouldn't close the overview
  property real _lastAction: 0
  function recentAction() {
    return Date.now() - root._lastAction < 1000;
  }

  // Esc: stop a drag or resize. False when there was none.
  function cancelInteraction() {
    return input.cancel();
  }

  function goTo(cell) {
    HyprlandManager.goToWorkspace(root.ids[cell], "go", root.monitor);
    root.closeRequested();
  }

  function focusWindow(address) {
    HyprlandManager.focusWindow(address);
    root.closeRequested();
  }

  function closeWindow(address) {
    root._lastAction = Date.now();
    HyprlandManager.closeWindow(address);
  }

  // A window dropped at a board point, its preview's corner at `corner`;
  // `cursor` is the pointer in overlay coordinates
  function dropWindow(address, cell, point, corner, cursor) {
    const win = root.byAddress[address];
    if (!win || cell < 0)
      return;
    const workspaceId = root.ids[cell];
    const same = win.workspace.id === workspaceId;
    root._lastAction = Date.now();
    if (win.floating) {
      const origin = WorkspaceGeometry.cellRect(cell, root.cellW, root.cellH, root.gap, root.columns);
      const at = root.workspaceOrigin(workspaceId);
      const size = root.itemFor(address)?.rect ?? {
        w: 0,
        h: 0
      };
      const x = Math.min(Math.max(corner.x - origin.x, 0), root.cellW - size.w);
      const y = Math.min(Math.max(corner.y - origin.y, 0), root.cellH - size.h);
      HyprlandManager.placeWindow(address, workspaceId, "", "", null, same, {
        x: at.x + x / root.miniScale,
        y: at.y + y / root.miniScale
      });
      return;
    }
    const target = root.dropTargetAt(cell, point, address);
    // Alone on its workspace: nowhere else to go
    if (same && !target)
      return;
    HyprlandManager.placeWindow(address, workspaceId, target?.address ?? "", target?.side ?? "", {
      x: root.monitorX + cursor.x,
      y: root.monitorY + cursor.y
    }, same, null);
  }

  // Where a tiled window dropped at a point lands (see WorkspaceGeometry)
  function dropTargetAt(cell, point, address) {
    const others = root.items.filter(item => item.cell === cell && !item.floating && item.address !== address);
    return WorkspaceGeometry.dropTarget(others, point.x, point.y, HyprlandManager.splitWidthMultiplier);
  }

  // A resize step, in board pixels
  function resizeWindow(address, dw, dh, dx, dy) {
    root._lastAction = Date.now();
    const s = root.miniScale;
    HyprlandManager.resizeWindow(address, dw / s, dh / s, dx / s, dy / s);
  }

  implicitWidth: board.width + root.pad * 2
  implicitHeight: board.height + root.pad * 2
  radius: Appearance.borderRadius
  color: Theme.background
  border.color: Theme.border
  border.width: Appearance.borderWidth

  // Clicks on the panel's margin don't reach the backdrop (which closes)
  MouseArea {
    anchors.fill: parent
    acceptedButtons: Qt.AllButtons
  }

  Item {
    id: board
    x: root.pad
    y: root.pad
    width: root.cellW * root.columns + root.gap * (root.columns - 1)
    height: root.cellH * root.rows + root.gap * (root.rows - 1)

    Repeater {
      model: root.ids.length

      WorkspaceCell {
        required property int index
        readonly property var rect: WorkspaceGeometry.cellRect(index, root.cellW, root.cellH, root.gap, root.columns)

        x: rect.x
        y: rect.y
        width: root.cellW
        height: root.cellH
        number: index + 1
        wallpaper: WorkspaceOverlayConfig.wallpaper ? Appearance.wallpaperFor(root.screen?.name ?? "") : ""
        color: WorkspaceOverlayConfig.color
        dim: WorkspaceOverlayConfig.dimInactive
        showNumber: WorkspaceOverlayConfig.showNumbers
        radius: root.cellRadius
        current: root.ids[index] === root.activeId
        hovered: input.hoveredCell === index && input.mode === ""
        dropTarget: input.mode === "drag" && input.dropCell === index
        // An empty workspace takes the whole cell
        dropFill: dropTarget && input.dropHint === null
      }
    }

    Repeater {
      model: ScriptModel {
        values: root._addressKey === "" ? [] : root._addressKey.split(",")
      }

      WindowPreview {
        id: preview
        required property string modelData
        readonly property var item: root.itemFor(modelData)
        readonly property var rect: item?.rect ?? {
          x: 0,
          y: 0,
          w: 0,
          h: 0
        }

        x: rect.x
        y: rect.y
        width: rect.w
        height: rect.h
        z: item?.floating ? 2 : 1
        visible: item !== null
        windowData: root.byAddress[modelData] ?? null
        capturing: root.active
        showTitle: WorkspaceOverlayConfig.showTitles
        radius: Math.max(2, root.cellRadius * 0.6)
        hovered: input.hoveredAddress === modelData && (input.mode === "" || input.mode === "resize")
        resizing: input.mode === "resize" && input.activeAddress === modelData
        opacity: input.mode === "drag" && input.activeAddress === modelData ? 0.3 : 1

        Behavior on x {
          enabled: !preview.resizing
          NumberAnimation {
            duration: Appearance.animFast
            easing.type: Appearance.easing
          }
        }
        Behavior on y {
          enabled: !preview.resizing
          NumberAnimation {
            duration: Appearance.animFast
            easing.type: Appearance.easing
          }
        }
        Behavior on width {
          enabled: !preview.resizing
          NumberAnimation {
            duration: Appearance.animFast
            easing.type: Appearance.easing
          }
        }
        Behavior on height {
          enabled: !preview.resizing
          NumberAnimation {
            duration: Appearance.animFast
            easing.type: Appearance.easing
          }
        }
      }
    }

    // Where a dragged tiled window will land
    Rectangle {
      id: dropBox
      readonly property var hint: input.dropHint
      // It appears in place and only animates between halves once shown;
      // otherwise it would fly in from the board's corner (0, 0)
      property bool animate: false
      onVisibleChanged: {
        dropBox.animate = false;
        if (dropBox.visible)
          Qt.callLater(() => dropBox.animate = dropBox.visible);
      }

      visible: input.mode === "drag" && hint !== null
      x: hint?.rect.x ?? 0
      y: hint?.rect.y ?? 0
      width: hint?.rect.w ?? 0
      height: hint?.rect.h ?? 0
      z: 3
      radius: Math.max(2, root.cellRadius * 0.6)
      color: Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.3)
      border.color: Theme.accent
      border.width: Appearance.borderWidth * 2

      Behavior on x {
        enabled: dropBox.animate
        NumberAnimation {
          duration: Appearance.animFast
          easing.type: Appearance.easing
        }
      }
      Behavior on y {
        enabled: dropBox.animate
        NumberAnimation {
          duration: Appearance.animFast
          easing.type: Appearance.easing
        }
      }
      Behavior on width {
        enabled: dropBox.animate
        NumberAnimation {
          duration: Appearance.animFast
          easing.type: Appearance.easing
        }
      }
      Behavior on height {
        enabled: dropBox.animate
        NumberAnimation {
          duration: Appearance.animFast
          easing.type: Appearance.easing
        }
      }
    }

    // The dragged window, under the pointer
    WindowPreview {
      readonly property var rect: root.itemFor(input.activeAddress)?.rect ?? {
        w: 0,
        h: 0
      }
      visible: input.mode === "drag"
      x: input.ghostX
      y: input.ghostY
      width: rect.w
      height: rect.h
      z: 4
      windowData: input.mode === "drag" ? root.byAddress[input.activeAddress] ?? null : null
      capturing: root.active && visible
      radius: Math.max(2, root.cellRadius * 0.6)
      hovered: true
      opacity: 0.9
    }

    OverviewInput {
      id: input
      anchors.fill: parent
      z: 5
      overview: root
    }
  }
}
