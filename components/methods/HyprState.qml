pragma Singleton
import QtQuick

// Hyprland's JSON replies (HyprlandManager) as the shapes the rest of the
// shell reads, which don't depend on the compositor: what another
// compositor's service would hand back too.
QtObject {
  id: root

  // The main keyboard's layouts from a j/devices reply: { layouts: ["us",
  // "de"], index (the active one's), keymap (its name) }, or null with no
  // keyboard
  function keyboard(devices) {
    const keyboards = devices?.keyboards ?? [];
    const main = keyboards.find(k => k.main) ?? keyboards[0];
    if (!main)
      return null;
    return {
      "layouts": String(main.layout ?? "").split(",").map(layout => layout.trim()).filter(layout => layout !== ""),
      "index": main.active_layout_index ?? 0,
      "keymap": main.active_keymap ?? ""
    };
  }

  // Each monitor's logical size and the layer surfaces on it, from j/monitors
  // and j/layers: { [monitor name]: { w, h, layers: [{ namespace, x, y, w,
  // h }] } }, layer positions relative to the monitor, all in logical px
  function layerRects(monitors, layers) {
    const result = {};
    for (const monitor of monitors ?? []) {
      const levels = layers?.[monitor.name]?.levels ?? {};
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
    return result;
  }
}
