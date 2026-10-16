pragma Singleton
import QtQuick

import qs.components.methods
import qs.config

/**
 * Where axiom's layer-shell windows are on their outputs, worked out by
 * axiom itself on every compositor (methods/LayerArrange; docs/dev/
 * compositor/layer-arrangement.md). Each window that needs to know, or
 * that reserves space others are placed against, reports how it asks to
 * be laid out (hosts/popout/LayerOrigin): anchors, margins, size, zone,
 * and when it mapped. Where the compositor can list its layers (Hyprland:
 * CompositorManager.withLayerRects), the result is checked against that
 * and each difference logged (console.log, "LayerManager:").
 */
QtObject {
  id: root

  // { owner uid: spec } as reported; spec: { output, namespace, layer,
  // anchors, margins, w, h, zone, mapped }
  property var _specs: ({})
  property int _lastUid: 0
  property int _lastSeq: 0
  property var _seqs: ({})

  // Every reported window's rect by output, as LayerArrange.arrange
  // gives it ({ [output]: { w, h, layers: [{ id, namespace, x, y, w, h }] } });
  // replaced only when something moved
  property var rects: ({})

  // A reporting window's id: owners keep it for their lifetime
  function register() {
    return ++root._lastUid;
  }

  // A window's layout, again whenever it changes; null once it's gone
  function report(uid, spec) {
    const specs = Object.assign({}, root._specs);
    const seqs = Object.assign({}, root._seqs);
    if (spec)
      specs[uid] = spec;
    else
      delete specs[uid];
    // Mapped from now on: arranged after everything mapped before it
    if (spec?.mapped && seqs[uid] === undefined)
      seqs[uid] = ++root._lastSeq;
    else if (!spec?.mapped)
      delete seqs[uid];
    root._specs = specs;
    root._seqs = seqs;
    root._arrange.restart();
  }

  // Where window `uid` is on its output ({ x, y, w, h }), or null when
  // it isn't laid out (no output, or reserving space and not mapped)
  function rectOf(uid, output) {
    return (root.rects[output]?.layers ?? []).find(l => l.id === uid) ?? null;
  }

  // The windows LayerArrange places: every mapped one, and those not yet
  // mapped that reserve nothing (so nothing else moves), where they'd go
  // if they mapped now
  function _surfaces() {
    const out = [];
    for (const uid in root._specs) {
      const spec = root._specs[uid];
      const seq = root._seqs[uid];
      if (seq === undefined && spec.zone > 0)
        continue;
      out.push(Object.assign({}, spec, {
        "id": Number(uid),
        "order": LayerStack.orderOf(spec.namespace),
        "seq": seq ?? root._lastSeq + 1
      }));
    }
    return out;
  }

  // Coalesces a burst of reports (a window resizing on every frame of an
  // animation) into one arrangement
  property Timer _arrange: Timer {
    interval: 0
    onTriggered: {
      const outputs = General.outputs.reduce((acc, screen) => {
        acc[screen.name] = {
          "w": screen.width,
          "h": screen.height
        };
        return acc;
      }, {});
      const next = LayerArrange.arrange(outputs, root._surfaces(), CompositorManager.supports.layerOrder === true);
      if (JSON.stringify(next) !== JSON.stringify(root.rects)) {
        root.rects = next;
        root._check.restart();
      }
    }
  }
  property Connections _outputs: Connections {
    target: General
    function onOutputsChanged() {
      root._arrange.restart();
    }
  }

  // --- The check against the compositor's own list ---

  // Each computed rect of a mapped window with no reported one in its
  // namespace at the same place and size. Reported only once it settles
  // (a window resized gets there a moment later), and once per new set.
  property string _lastMismatch: ""
  property Timer _check: Timer {
    interval: 600
    onTriggered: CompositorManager.withLayerRects(reported => {
      if (!reported)
        return;
      const misses = [];
      for (const output in root.rects)
        for (const l of root.rects[output].layers) {
          if (root._seqs[l.id] === undefined)
            continue;
          const theirs = (reported[output]?.layers ?? []).filter(r => r.namespace === l.namespace);
          if (theirs.some(r => r.x === l.x && r.y === l.y && r.w === l.w && r.h === l.h))
            continue;
          misses.push(`${l.namespace} on ${output} computed ${l.x},${l.y} ${l.w}x${l.h}; reported ${theirs.map(r => `${r.x},${r.y} ${r.w}x${r.h}`).join(" | ") || "none"}`);
        }
      const text = misses.sort().join("\n");
      if (text !== root._lastMismatch && text !== "")
        console.log("LayerManager: differs from the compositor:\n" + text);
      root._lastMismatch = text;
    })
  }
  property Connections _layerEvents: Connections {
    target: CompositorManager
    function onLayersChanged() {
      root._check.restart();
    }
  }
}
