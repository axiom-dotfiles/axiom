pragma Singleton
import QtQuick
import Quickshell

import qs.services
import qs.components.methods

QtObject {
  enum Location {
    Top,
    Bottom,
    Left,
    Right
  }
  // Adds derived orientation flags to a bar entry from the Bars section
  // (whose keys are always filled in from the schema defaults).
  function enrichBarConfig(barConfig) {
    const loc = Bar.getLocationFromString(barConfig.location);
    // The bar is sized by its widgets, never the other way round, so no
    // setting can leave them cut off
    const widgetSize = barConfig.widgetSize;
    const padding = barConfig.padding;
    const background = barConfig.background ?? "solid";
    const pills = background === "pills";
    const solid = background === "solid";
    const floating = !solid && Appearance.screenBorder;
    // What covers the bar's own pixels: a floating bar's outer edge lies on
    // the border's stroke, and a solid bar with the border off draws its own
    // stroke on its inner edge. A solid bar's border strip only draws its
    // stroke past the bar (RoundedBorders.frameColorFor).
    const outerCover = floating ? Appearance.borderWidth : 0;
    const innerCover = solid && !Appearance.screenBorder ? Appearance.borderWidth : 0;
    // A solid bar reaches at least as far as the border strip laid over its
    // inner part (BarPanel.reservedZone), so no gap opens under the strip
    const minExtent = solid && Appearance.screenBorder ? Appearance.screenMargin - Appearance.borderWidth : 0;
    const plainExtent = Math.max(minExtent, outerCover + padding + widgetSize + padding + innerCover);
    // A pill covers the screen border's stroke where it joins it
    const overlap = Appearance.screenBorder ? Appearance.borderWidth : 0;
    // Padding past the border's stroke on the pill's outer side, so its
    // widgets sit the frame plus this in from the screen edge
    const pillPad = barConfig.pillPadding ?? 0;
    // How far a pill's widgets sit in from the bar's outer edge (and its
    // ends): past the border stroke, or with the border off, the screen
    // margin the frame would have taken, so they keep the same gap from the
    // bare screen edge
    const pillInset = overlap + (Appearance.screenBorder ? 0 : Appearance.screenMargin) + pillPad;
    // The widgets' gap to every edge they're seen against: the screen edge
    // (through the frame), and the pill's inner side and free ends (to the
    // outside of its stroke)
    const pillGap = Math.max(Appearance.borderWidth, Appearance.screenMargin + pillPad);
    // How far a pill reaches in from the bar's outer edge: the inset, its
    // widgets, and the gap to its far side
    const pillDepth = pillInset + widgetSize + pillGap;

    return {
      "id": barConfig.id,
      // The config entry's id: a bar on every monitor has one per screen
      "sourceId": barConfig.sourceId ?? barConfig.id,
      "enabled": barConfig.enabled,
      "monitor": barConfig.monitor,
      // A pill bar is as thick as its pills, so the padding always fits
      // and nothing is left between them and the windows
      "extent": pills ? pillDepth : plainExtent,
      "widgetSize": widgetSize,
      "padding": padding,
      // How far the widgets sit in from the bar's outer edge: past the
      // stroke and pill padding, or centred between whatever covers the bar
      "crossStart": pills ? pillInset : outerCover + (plainExtent - outerCover - innerCover - widgetSize) / 2,
      "background": background,
      "pills": pills,
      // Transparent and pill bars sit inside the screen border, not under it
      "floating": floating,
      // A solid bar's inner stroke is the border strip's; with the border
      // off it draws its own, on its innermost pixels
      "innerStroke": solid && !Appearance.screenBorder,
      "overlap": overlap,
      "pillInset": pillInset,
      "pillGap": pillGap,
      "pillMerge": barConfig.pillMerge ?? 0,
      "pillDepth": pillDepth,
      "spacing": barConfig.spacing,
      // What's drawn inside the bar follows the bar, never the Widget
      // section (that's for panels, popouts and controls)
      "widgetPadding": barConfig.widgetPadding,
      "widgetSpacing": barConfig.widgetSpacing,
      "fontSize": barConfig.overrideFontSize ? barConfig.fontSize : Appearance.fontSize,
      // Widget chips only, else the interior radius: pills and fillets keep
      // Appearance's, to meet the border
      "radius": barConfig.overrideRadius ? barConfig.widgetRadius : Widget.radius,
      // Off: widgets draw straight onto the bar in widgetTextColor (a
      // color name; see widgetForeground)
      "widgetBackgrounds": barConfig.widgetBackgrounds,
      "widgetTextColor": barConfig.widgetTextColor,
      "lockCenter": barConfig.lockCenter,
      "location": loc,
      "reserveSpace": barConfig.reserveSpace,
      "widgets": barConfig.widgets,
      "vertical": loc === Bar.Left || loc === Bar.Right,
      "left": loc === Bar.Left,
      "right": loc === Bar.Right,
      "top": loc === Bar.Top,
      "bottom": loc === Bar.Bottom
    };
  }

  // What a bar widget draws its text and icons in: its own color (`name`,
  // chosen to read on its background), or the bar's with widget
  // backgrounds off
  function widgetForeground(barConfig, name) {
    return Theme.resolveColor(barConfig.widgetBackgrounds ? name : barConfig.widgetTextColor);
  }

  // The Bars section as saved: no previews, "*" monitors unexpanded, locations as strings
  readonly property var savedBars: ConfigManager.config.Bars
  // The running bars: while the bar editor has unsaved edits, those
  readonly property var bars: Bar.expandBars(ConfigManager.previews.Bars ?? ConfigManager.config.Bars).map(bar => Bar.enrichBarConfig(bar))

  // A bar on every monitor (`monitor: "*"`) becomes one entry per screen,
  // each with its own id (keying its BarPanel) and that screen as its
  // monitor. Any other bar's monitor is resolved like a dock's or edge
  // menu's: its named screen, else (empty or not connected) the primary
  // monitor.
  function expandBars(bars) {
    const names = Array.from(Quickshell.screens).map(s => s.name);
    return [].concat(...bars.map(bar => {
      if (bar.monitor !== "*")
        return [Object.assign({}, bar, {
            "monitor": General.screensNamed(bar.monitor)[0]?.name ?? ""
          })];
      return names.map(name => Object.assign({}, bar, {
          "id": `${bar.id}@${name}`,
          "sourceId": bar.id,
          "monitor": name
        }));
    }));
  }

  // A widget's `layout` overrides (size, minSize, priority), for the bar
  // editor's inspector
  readonly property var widgetLayoutSchema: ConfigManager.configSchema.definitions.WidgetLayout
  // A bar's own fields in groups (`x-group`), for the bar editor
  readonly property var fieldGroups: SchemaLayout.objectGroups(ConfigManager.configSchema.definitions.Bar, ["widgets"])

  readonly property var availableWidgetTypes: {
    const oneOf = ConfigManager.configSchema?.definitions?.BarWidget?.oneOf || [];
    return oneOf.map(refObj => {
      const refName = refObj.$ref.replace("#/definitions/", "");
      const def = ConfigManager.configSchema.definitions[refName];
      if (!def)
        return null;
      return {
        "type": def.properties?.type?.const,
        "label": def.properties?.type?.description || def.properties?.type?.const,
        // Material Symbols name (`x-icon`)
        "icon": def["x-icon"] ?? "widgets",
        "propertiesSchema": def.properties?.properties?.properties || null
      };
    }).filter(t => t !== null);
  }
  // The enabled bars on a screen by edge ({ top, bottom, left, right },
  // null where there is none)
  function edgesFor(screen) {
    const edges = {
      "top": null,
      "bottom": null,
      "left": null,
      "right": null
    };
    Bar.bars.forEach(bar => {
      if (!bar.enabled || bar.monitor !== screen?.name)
        return;
      const edge = bar.top ? "top" : bar.bottom ? "bottom" : bar.left ? "left" : "right";
      if (!edges[edge])
        edges[edge] = bar;
    });
    return edges;
  }

  // Whether a screen edge (a Bar.Location) is bare: no screen border and no
  // bar on it, so surfaces there run straight off the screen
  function screenEdgeOpen(screen, location) {
    if (Appearance.screenBorder)
      return false;
    return !Bar.edgesFor(screen)[Bar.edgeName(location)];
  }

  // A Bar.Location as the edge names zones and Hyprland use: "top" |
  // "bottom" | "left" | "right"
  function edgeName(location) {
    return ["top", "bottom", "left", "right"][location];
  }

  function getLocationFromString(locStr) {
    switch (locStr) {
    case "Top":
      return Bar.Top;
    case "Bottom":
      return Bar.Bottom;
    case "Left":
      return Bar.Left;
    case "Right":
      return Bar.Right;
    default:
      return Bar.Top;
    }
  }
}
