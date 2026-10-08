pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland

import qs.config

/**
 * The blur behind the shell's chrome: the border's frame, bars and their
 * popouts, edge popouts, integrated edge menus and docks. Each surface
 * registers its shape (BlurShape); one click-through window per screen
 * (shell/BlurBacking) draws them all, filled, and is the only one of them
 * Hyprland blurs. Blurred in one pass, before any chrome is drawn, the
 * blur behind joined surfaces matches exactly; the surfaces themselves
 * draw their outer fill transparent (`backing`).
 * Layer-shell windows don't know where they are on screen, so their
 * origins are read from Hyprland (`hyprctl layers`), again whenever a
 * layer maps or unmaps, or a window asks (it resized, reservations moved),
 * while surfaces are translucent (the joins in the border's stroke use
 * them too).
 */
QtObject {
  id: root

  // Whether anything blurs now: Appearance.blur, paused while a fullscreen
  // window is open on any screen (Appearance.blurPauseFullscreen; the
  // layer rules are Hyprland-wide). The chrome then fills itself.
  readonly property bool paused: Appearance.blur && Appearance.blurPauseFullscreen && Quickshell.screens.some(screen => HyprlandManager.hasFullscreen(screen.name))
  readonly property bool active: Appearance.blur && !root.paused
  // The surfaces leave their fill to the backing
  readonly property bool backing: root.active

  // The registered BlurShapes; changes only as one comes or goes. Each
  // gets a `uid`, which the blur window keys its copies by (shapeOf).
  property var shapes: []
  property int _lastUid: 0
  property var _byUid: ({})

  function register(shape) {
    if (root.shapes.includes(shape))
      return;
    shape.uid = ++root._lastUid;
    root._byUid[shape.uid] = shape;
    root.shapes = root.shapes.concat([shape]);
  }

  function unregister(shape) {
    if (!root.shapes.includes(shape))
      return;
    delete root._byUid[shape.uid];
    root.shapes = root.shapes.filter(s => s !== shape);
  }

  // The registered shape with that uid, or null once it's gone
  function shapeOf(uid) {
    return root._byUid[uid] ?? null;
  }

  // { monitorName: { w, h, layers: [{ namespace, x, y, w, h }] } },
  // monitor-relative
  property var layers: ({})

  /**
   * Where a layer window is on its monitor, null until Hyprland has
   * reported it. Every window asking spans its `edge` (a Bar.Location),
   * anchored there: the mapped one in `namespace` that runs as far along
   * it, on that side of the screen, nearest the edge where several do.
   * Grown or shrunk across it (an edge popout's content), it's placed from
   * the side it's anchored to until Hyprland reports it again, rather than
   * lost for those frames. A window mapped only while open gets where it
   * was last seen, so it's backed from its first frame.
   */
  function layerOrigin(namespace, monitor, width, height, edge) {
    const vertical = edge === Bar.Left || edge === Bar.Right;
    const along = vertical ? height : width;
    const cacheKey = [namespace, monitor, Math.round(along), edge].join("|");
    const screen = root.layers[monitor];
    const onSide = l => {
      if (!screen)
        return false;
      const centre = vertical ? l.x + l.w / 2 : l.y + l.h / 2;
      const half = (vertical ? screen.w : screen.h) / 2;
      return edge === Bar.Left || edge === Bar.Top ? centre <= half : centre >= half;
    };
    const matches = (screen?.layers ?? []).filter(l => l.namespace === namespace && Math.abs((vertical ? l.h : l.w) - along) <= 1 && onSide(l));
    let best = root._seen[cacheKey] ?? null;
    if (matches.length > 0) {
      // Its own size first, then nearest the edge
      const depth = vertical ? width : height;
      const miss = l => Math.abs((vertical ? l.w : l.h) - depth) > 1 ? 1 : 0;
      const key = l => edge === Bar.Left ? l.x : edge === Bar.Right ? -(l.x + l.w) : edge === Bar.Top ? l.y : -(l.y + l.h);
      best = matches.reduce((a, b) => miss(b) < miss(a) || (miss(b) === miss(a) && key(b) < key(a)) ? b : a);
      // Kept without notifying: read only when nothing current matches
      root._seen[cacheKey] = best;
    }
    if (!best)
      return null;
    // From the side it's anchored to
    return Qt.point(edge === Bar.Right ? best.x + best.w - width : best.x, edge === Bar.Bottom ? best.y + best.h - height : best.y);
  }
  property var _seen: ({})

  // Nothing reads an origin while surfaces are solid
  readonly property bool _needed: Appearance.translucent
  on_NeededChanged: {
    if (root._needed)
      root.refreshLayers();
  }

  function refreshLayers() {
    if (root._needed)
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
            // Layer geometry is in logical px, as the monitor's size isn't
            const scale = monitor.scale || 1;
            const turned = monitor.transform % 2 === 1;
            result[monitor.name] = {
              "w": (turned ? monitor.height : monitor.width) / scale,
              "h": (turned ? monitor.width : monitor.height) / scale,
              "layers": [].concat(...Object.keys(levels).map(level => levels[level])).map(l => ({
                    "namespace": l.namespace,
                    "x": l.x - monitor.x,
                    "y": l.y - monitor.y,
                    "w": l.w,
                    "h": l.h
                  }))
            };
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
