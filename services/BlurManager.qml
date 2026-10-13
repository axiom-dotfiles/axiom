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
 * layer maps or unmaps, or a window asks (it resized, reservations moved).
 * The joins in the border's stroke and popouts' footprints (PopoutManager)
 * use them too, so they're kept whatever the surfaces look like.
 */
QtObject {
  id: root

  // Whether anything blurs now: Appearance.blur, paused while a fullscreen
  // window is open on any screen (Appearance.blurPauseFullscreen; the
  // layer rules are Hyprland-wide). The chrome then fills itself, solid on
  // the screens showing one (opaqueOn).
  readonly property bool paused: Appearance.blur && Appearance.blurPauseFullscreen && Quickshell.screens.some(screen => HyprlandManager.hasFullscreen(screen.name))
  readonly property bool active: Appearance.blur && !root.paused
  // The surfaces leave their fill to the blur window: blurring, and its
  // windows built (BlurBacking waits for the layer rules, as the chrome does)
  readonly property bool backing: root.active && HyprlandManager.layerRulesReady

  function _name(screen) {
    return typeof screen === "string" ? screen : screen?.name ?? "";
  }

  // Whether a chrome surface on `screen` (a ShellScreen or its name) leaves
  // its fill to the blur window. `onOverlay`: its window is on the Overlay
  // layer, over the overlay (which covers the blur window, so it fills
  // itself while the overlay is open there) and over fullscreen windows
  // (where the blur window rises too: overFullscreen). Otherwise it's on
  // Top, faded out under a fullscreen window, and its copy goes with it.
  function backsOn(screen, onOverlay) {
    if (!root.backing)
      return false;
    const name = root._name(screen);
    return onOverlay ? !ShellManager.surfaceOpenOn("overlay", name) : !HyprlandManager.hasFullscreen(name);
  }

  // Whether the blur window on `screen` stands on the Overlay layer: a
  // fullscreen window shown there hides the Top layer, and the surfaces
  // over it still blur
  function overFullscreen(screen) {
    return root.backing && HyprlandManager.hasFullscreen(root._name(screen));
  }

  // Whether surfaces on `screen` fill themselves solid: blur paused for a
  // fullscreen window shown there (elsewhere they stay translucent)
  function opaqueOn(screen) {
    return root.paused && HyprlandManager.hasFullscreen(root._name(screen));
  }

  // A surface's own fill on `screen`: at the surface opacity, solid where
  // opaqueOn
  function fillOn(color, screen) {
    return root.opaqueOn(screen) ? color : Appearance.fill(color);
  }

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
      const half = (vertical ? screen.w : screen.h) / 2;
      // A window reaching past the middle (an edge popout deep enough for
      // its content, filling the room between the edges' reservations)
      // is where it is whichever edge it's anchored to
      if ((vertical ? l.w : l.h) >= half)
        return true;
      const centre = vertical ? l.x + l.w / 2 : l.y + l.h / 2;
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
  // Last seen per window size: grows by one small entry per length a
  // window has had, and starts over on a reload
  property var _seen: ({})

  function refreshLayers() {
    root._refresh.restart();
  }

  // Windows mapped whose origin is still unknown (LayerOrigin): a window
  // resized in place sends no layer event, and the ask may have come
  // before Hyprland had its new size, so the layers are read again a few
  // times while any waits, then not until one starts waiting anew
  property var _awaiting: []
  property int _awaitTries: 0
  function awaitOrigin(owner, waiting) {
    const others = root._awaiting.filter(o => o !== owner);
    root._awaiting = waiting ? others.concat([owner]) : others;
    if (waiting)
      root._awaitTries = 0;
  }
  property Timer _awaitRetry: Timer {
    interval: 250
    repeat: true
    running: root._awaiting.length > 0 && root._awaitTries < 8
    onTriggered: {
      root._awaitTries += 1;
      root.refreshLayers();
    }
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
