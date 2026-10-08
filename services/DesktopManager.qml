pragma Singleton
import QtQuick
import Quickshell

import qs.config
import qs.components.methods

/* The desktop's modules: the layouts editor's draft of the Desktop section
 * (`editor`, shown live on the desktop while it differs from the config),
 * which of its layouts is edited (`selectedTarget`: "all", "primary" or a
 * monitor's name), and the room each screen's desktop has.
 *
 * A monitor shows its own layout (Desktop.monitors) if it has one, else
 * the primary monitor's on the primary monitor, else the one for all
 * monitors (DesktopConfig.sourceFor): a monitor without one of its own is
 * edited by giving it one (createForTarget), a copy of what it showed. */
QtObject {
  id: root

  // "all" | "primary" | a monitor's name
  readonly property string selectedTarget: root._selectedTarget
  property string _selectedTarget: "primary"

  property ScreenLayoutEditor editor: ScreenLayoutEditor {
    path: ["Desktop"]
    host: "desktop"
    name: I18n.tr("Desktop")
    scope: root.selectedTarget
    previewSection: "Desktop"
    layoutOf: local => root.layoutIn(local, root.selectedTarget)
    layoutsOf: local => local ? [
        {
          "layout": local.all,
          "name": I18n.tr("Desktop (all monitors)")
        },
        {
          "layout": local.primary,
          "name": I18n.tr("Desktop (primary monitor)")
        }
      ].concat(local.monitors.map(layout => ({
            "layout": layout,
            "name": I18n.tr("Desktop ({0})", layout.monitor)
          }))) : []
  }

  // The selected target's own layout in the draft, null when it has none
  // (a monitor showing another's)
  readonly property var selectedLayout: root.editor.localLayout
  readonly property var _desktop: root.editor.local

  // The layout `key` names in a Desktop section, or null
  function layoutIn(desktop, key) {
    if (!desktop)
      return null;
    if (key === "all")
      return desktop.all;
    if (key === "primary")
      return desktop.primary;
    return desktop.monitors.find(layout => layout.monitor === key) ?? null;
  }

  function selectTarget(key) {
    if (key === root._selectedTarget)
      return;
    root.editor.layout.clearSelection();
    root._selectedTarget = key;
  }

  // What can be edited, [{ key, label, status }]: all monitors, the
  // primary monitor, then each monitor (plugged in, then those with a
  // layout of their own that aren't), with what each shows
  readonly property var targets: {
    const desktop = root._desktop;
    if (!desktop)
      return [];
    const screens = Array.from(Quickshell.screens);
    const names = screens.map(screen => screen.name);
    desktop.monitors.forEach(layout => {
      if (!names.includes(layout.monitor))
        names.push(layout.monitor);
    });
    const onOff = layout => layout.enabled ? I18n.tr("On") : I18n.tr("Off");
    const out = [
      {
        "key": "all",
        "label": I18n.tr("All monitors"),
        "status": onOff(desktop.all)
      },
      {
        "key": "primary",
        "label": DesktopConfig.primaryName ? I18n.tr("Primary monitor ({0})", DesktopConfig.primaryName) : I18n.tr("Primary monitor"),
        "status": onOff(desktop.primary)
      }
    ];
    names.forEach(name => {
      const screen = screens.find(s => s.name === name);
      out.push({
        "key": name,
        "label": screen ? (screen.model ? I18n.tr("{0} · {1}", name, screen.model) : name) : I18n.tr("{0} · not connected", name),
        "status": root.statusOf(name, desktop)
      });
    });
    return out;
  }

  // What the monitor named `name` shows, in words
  function statusOf(name, desktop) {
    switch (DesktopConfig.sourceFor(name, desktop)) {
    case "monitor":
      return I18n.tr("Own layout");
    case "primary":
      return I18n.tr("Uses the primary monitor's");
    case "all":
      return I18n.tr("Uses all monitors'");
    }
    return root.layoutIn(desktop, name) ? I18n.tr("Off") : I18n.tr("Shows nothing");
  }

  // The selected monitor gets a layout of its own: a copy of the one it
  // shows, else an empty one
  function createForTarget() {
    const name = root.selectedTarget;
    if (name === "all" || name === "primary" || root.selectedLayout)
      return;
    root.editor.edit(desktop => {
      const source = DesktopConfig.sourceFor(name, desktop);
      const shown = source === "primary" || source === "all" ? root.layoutIn(desktop, source) : null;
      const layout = shown ? Utils.clone(shown) : ConfigManager.withDefaults({}, "DesktopLayout");
      layout.monitor = name;
      layout.enabled = true;
      desktop.monitors.push(layout);
    });
    root.editor.layout.clearHistory();
  }

  // The selected monitor's own layout goes: it shows the primary
  // monitor's or all monitors' again. A monitor that isn't plugged in
  // leaves the picker with it, so the primary monitor is selected instead
  function removeTarget() {
    const name = root.selectedTarget;
    if (name === "all" || name === "primary")
      return;
    root.editor.layout.clearSelection();
    root.editor.edit(desktop => {
      desktop.monitors = desktop.monitors.filter(layout => layout.monitor !== name);
    });
    root.editor.layout.clearHistory();
    if (!Array.from(Quickshell.screens).some(screen => screen.name === name))
      root.selectTarget("primary");
  }

  function setEnabled(enabled) {
    if (!root.selectedLayout || root.selectedLayout.enabled === enabled)
      return;
    root.editor.updateLayoutField("enabled", enabled);
  }

  // --- Room ---

  // The screen a target is laid out on: its monitor, else the primary
  // monitor (for all monitors, and a monitor that isn't plugged in)
  function screenFor(key) {
    const screens = Array.from(Quickshell.screens);
    return screens.find(screen => screen.name === key) ?? screens.find(screen => screen.name === DesktopConfig.primaryName) ?? screens[0] ?? null;
  }

  // The room kept clear on each side of a screen's desktop ({ left, top,
  // right, bottom } px): what axiom reserves there (the border, bars,
  // integrated edge menus), or what Hyprland says is reserved (docks too)
  // if more, then Hyprland's gaps_out, so the grid lines up with where
  // tiled windows start
  function insetsFor(screen) {
    if (!screen)
      return {
        "left": 0,
        "top": 0,
        "right": 0,
        "bottom": 0
      };
    const reserved = DockManager.reservedOf(screen);
    const side = (location, index) => Math.max(EdgeMenuManager.reservedOn(screen, location), reserved[index]) + (HyprlandManager.gapsOut[Bar.edgeName(location)] ?? 0);
    return {
      "left": side(Bar.Left, 0),
      "top": side(Bar.Top, 1),
      "right": side(Bar.Right, 2),
      "bottom": side(Bar.Bottom, 3)
    };
  }
}
