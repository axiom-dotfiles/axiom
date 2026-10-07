pragma Singleton
import QtQuick
import Quickshell.Io
import Quickshell.Hyprland

import qs.config

/**
 * The blur behind the shell's chrome (prototype: bars and their popouts).
 * Each surface registers its shape (BlurShape); one click-through window
 * per screen (shell/BlurBacking) draws them all, filled, and is the only
 * one of them Hyprland blurs. Blurred in one pass, before any chrome is
 * drawn, the blur behind joined surfaces matches exactly; the surfaces
 * themselves draw their outer fill transparent (`backing`).
 * Layer-shell windows don't know where they are on screen, so their
 * origins are read from Hyprland (`hyprctl layers`), again whenever a
 * layer maps or unmaps, or a window asks (it resized, reservations moved).
 */
QtObject {
  id: root

  // The surfaces leave their fill to the backing
  readonly property bool backing: Appearance.blur

  // The registered BlurShapes; changes only as one comes or goes
  property var shapes: []

  function register(shape) {
    if (!root.shapes.includes(shape))
      root.shapes = root.shapes.concat([shape]);
  }

  function unregister(shape) {
    if (root.shapes.includes(shape))
      root.shapes = root.shapes.filter(s => s !== shape);
  }

  // { monitorName: [{ namespace, x, y, w, h }] }, monitor-relative
  property var layers: ({})

  // Where a layer window is on its monitor: the mapped one in `namespace`
  // that is `width` × `height`, the one nearest `edge` (a Bar.Location)
  // where several match; null until Hyprland has reported it
  // where several match; null until Hyprland has reported it. A window
  // mapped only while open (an edge popout) gets where the same window was
  // last seen, so it's backed from its first frame; it's read again as it
  // maps.
  function layerOrigin(namespace, monitor, width, height, edge) {
    const cacheKey = [namespace, monitor, Math.round(width), Math.round(height), edge].join("|");
    const matches = (root.layers[monitor] ?? []).filter(l => l.namespace === namespace && Math.abs(l.w - width) <= 1 && Math.abs(l.h - height) <= 1);
    if (matches.length === 0)
      return root._seen[cacheKey] ?? null;
    const key = l => edge === Bar.Left ? l.x : edge === Bar.Right ? -(l.x + l.w) : edge === Bar.Top ? l.y : -(l.y + l.h);
    const best = matches.reduce((a, b) => key(b) < key(a) ? b : a);
    const origin = Qt.point(best.x, best.y);
    // Kept without notifying: read only when nothing current matches
    root._seen[cacheKey] = origin;
    return origin;
  }
  property var _seen: ({})

  function refreshLayers() {
    root._refresh.restart();
  }

  property Timer _refresh: Timer {
    interval: 30
    onTriggered: {
      if (root._query.running)
        root._again = true;
      else
        root._query.running = true;
    }
  }
  property bool _again: false

  property Process _query: Process {
    command: ["sh", "-c", "printf '[%s,%s]' \"$(hyprctl -j monitors)\" \"$(hyprctl -j layers)\""]
    stdout: StdioCollector {
      onStreamFinished: {
        try {
          const [monitors, layers] = JSON.parse(text);
          const result = {};
          for (const monitor of monitors) {
            const levels = layers[monitor.name]?.levels ?? {};
            result[monitor.name] = [].concat(...Object.keys(levels).map(level => levels[level])).map(l => ({
                  "namespace": l.namespace,
                  "x": l.x - monitor.x,
                  "y": l.y - monitor.y,
                  "w": l.w,
                  "h": l.h
                }));
          }
          root.layers = result;
        } catch (e) {
          console.warn("[BlurManager] Couldn't read hyprctl layers:", e);
        }
      }
    }
    onExited: {
      if (root._again) {
        root._again = false;
        root._refresh.restart();
      }
    }
  }

  property Connections _events: Connections {
    target: Hyprland

    function onRawEvent(event) {
      if (event.name === "openlayer" || event.name === "closelayer" || event.name === "monitoradded" || event.name === "monitorremoved" || event.name === "configreloaded")
        root.refreshLayers();
    }
  }

  Component.onCompleted: root.refreshLayers()
}
