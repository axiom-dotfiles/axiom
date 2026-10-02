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
    // Its widget style, accents and shadow: BarStyle's, or its own
    const look = Bar.lookOf(barConfig);
    // The bar is sized by its widgets, never the other way round, so no
    // setting can leave them cut off
    const widgetSize = barConfig.widgetSize;
    const padding = barConfig.padding;
    const background = barConfig.background ?? "solid";
    const pills = background === "pills";
    const solid = background === "solid";
    // Floating bars are islands held off the edge: one along the bar, or
    // one per group of widgets
    const island = background === "floating" || background === "floatingPills";
    // Every bar but a solid one sits inside the screen border
    const insideBorder = !solid && Appearance.screenBorder;
    // What covers the bar's own pixels: the outer edge of a bar inside the
    // border lies on the border's stroke, and a solid bar with the border
    // off draws its own stroke on its inner edge. A solid bar's border strip
    // only draws its stroke past the bar (RoundedBorders.frameColorFor).
    const outerCover = insideBorder ? Appearance.borderWidth : 0;
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
    // An island sits `floatGap` in from the border's stroke (or the bare
    // screen edge), across the bar and from both its ends, and holds the
    // widgets and their padding inside a stroke
    const islandStart = outerCover + barConfig.floatGap;
    const islandDepth = Appearance.borderWidth + padding + widgetSize + padding + Appearance.borderWidth;
    const borderShadowed = solid && Appearance.screenBorder && barConfig.reserveSpace;
    // Shapes and grouping are for widgets drawn on a background
    const boxed = ["filled", "tinted", "outline"].includes(look.widgetStyle);
    const grouping = boxed ? look.widgetGrouping : "separate";

    return {
      "id": barConfig.id,
      // The config entry's id: a bar on every monitor has one per screen
      "sourceId": barConfig.sourceId ?? barConfig.id,
      "enabled": barConfig.enabled,
      "monitor": barConfig.monitor,
      // A pill bar is as thick as its pills, so the padding always fits
      // and nothing is left between them and the windows
      "extent": pills ? pillDepth : island ? islandStart + islandDepth : plainExtent,
      "widgetSize": widgetSize,
      "padding": padding,
      // How far the widgets sit in from the bar's outer edge: past the
      // stroke and pill padding, or centred between whatever covers the bar
      "crossStart": pills ? pillInset : island ? islandStart + Appearance.borderWidth + padding : outerCover + (plainExtent - outerCover - innerCover - widgetSize) / 2,
      "background": background,
      "solid": solid,
      "pills": pills,
      "island": island,
      "islandPills": background === "floatingPills",
      // Where islands start, in from the bar window's outer edge and both
      // its ends, and the gap from their widgets to their ends
      "islandStart": islandStart,
      "floatGap": island ? barConfig.floatGap : 0,
      "islandGap": Appearance.borderWidth + padding,
      "insideBorder": insideBorder,
      // An inner stroke surfaces on its edge can join: a solid bar's
      "joinable": solid,
      // A solid bar's inner stroke is the border strip's; with the border
      // off it draws its own, on its innermost pixels
      "innerStroke": solid && !Appearance.screenBorder,
      "overlap": overlap,
      "pillInset": pillInset,
      "pillGap": pillGap,
      "pillMerge": barConfig.pillMerge ?? 0,
      "pillDepth": pillDepth,
      "spacing": barConfig.spacing,
      // Between the widgets within a section: a powerline's touch
      "groupSpacing": grouping === "powerline" ? 0 : barConfig.spacing,
      // What's drawn inside the bar follows the bar, never the Widget
      // section (that's for panels, popouts and controls)
      "widgetPadding": barConfig.widgetPadding,
      "widgetSpacing": barConfig.widgetSpacing,
      "fontSize": barConfig.overrideFontSize ? barConfig.fontSize : Appearance.fontSize,
      // Widget chips only, else the interior radius: pills and fillets keep
      // Appearance's, to meet the border
      "radius": barConfig.overrideRadius ? barConfig.widgetRadius : Widget.radius,
      // How widgets show their colors (see widgetColors); the color
      // names stay unresolved
      "widgetStyle": look.widgetStyle,
      "tintOpacity": look.tintOpacity / 100,
      "outlineWidth": look.outlineWidth,
      "lineWidth": look.lineWidth,
      "lineSide": look.lineSide,
      "widgetTextColor": look.widgetTextColor,
      "widgetShape": boxed ? look.widgetShape : "rounded",
      "widgetEnds": look.widgetEnds,
      "widgetGrouping": grouping,
      "groupColor": look.groupColor,
      // A powerline's widgets touch, leaving no gap to divide
      "separatorStyle": grouping === "powerline" ? "none" : look.separatorStyle,
      "separatorColor": look.separatorColor,
      "separatorThickness": look.separatorThickness,
      "accentLine": look.accentLine,
      "accentLineColor": look.accentLineColor,
      "accentLineFade": look.accentLineFade,
      "accentLineWidth": look.accentLineWidth,
      // Cast by what the bar paints: a transparent one paints nothing. A
      // solid bar reserving its edge under the border leaves it to the
      // border, whose stroke is its inner edge (RoundedBorders)
      "shadow": background === "transparent" || borderShadowed ? "none" : look.shadow,
      "shadowColor": look.shadowColor,
      "shadowSize": look.shadowSize,
      // How far past the bar a shadow reaches (its blur and offset), which
      // the bar window takes on its inner side
      "shadowReach": background !== "transparent" && !borderShadowed && look.shadow !== "none" ? Math.ceil(look.shadowSize * 1.25) : 0,
      "lockCenter": barConfig.lockCenter,
      "location": loc,
      "reserveSpace": barConfig.reserveSpace,
      // Each Auto color picked for its place on this bar
      "widgets": Bar.withAutoColors(barConfig.widgets, look.widgetStyle, grouping, look.groupColor),
      "vertical": loc === Bar.Left || loc === Bar.Right,
      "left": loc === Bar.Left,
      "right": loc === Bar.Right,
      "top": loc === Bar.Top,
      "bottom": loc === Bar.Bottom
    };
  }

  // What a bar widget draws in on its bar ({ fill, stroke, indicator,
  // text, icon }, see BarWidgetStyle): `accent` is its color for its state,
  // `foregroundName` the text color it's configured with
  function widgetColors(barConfig, accent, foregroundName) {
    return BarWidgetStyle.colors(Bar._widgetStyle(barConfig, barConfig.widgetGrouping === "merged"), accent, Theme.resolveColor(foregroundName));
  }

  // What a merged run of widgets draws its shared background in
  function groupColors(barConfig) {
    const group = Theme.resolveColor(barConfig.groupColor);
    return BarWidgetStyle.colors(Bar._widgetStyle(barConfig, false), group, BarWidgetStyle.readableOn(group, Theme.foreground));
  }

  // A bar's widgets (by section) with each Auto color field (`x-autoColor`,
  // left empty) set to the color BarAutoColors picks for it among its shown
  // neighbours, seen against the bar or, filled and merged, the run
  function withAutoColors(widgets, widgetStyle, grouping, groupColor) {
    const shown = [].concat(...Bar.sectionNames.map(section => (widgets?.[section] ?? []).map((widget, index) => ({
            "section": section,
            "index": index,
            "widget": widget
          })))).filter(entry => entry.widget.visible !== false);
    const fields = shown.map(entry => {
      const roles = Bar.autoColorFields[entry.widget.type] ?? {};
      const properties = entry.widget.properties ?? {};
      return {
        "roles": roles,
        "set": Object.keys(roles).filter(key => properties[key]).reduce((set, key) => {
          set[key] = Theme.resolveColor(properties[key]);
          return set;
        }, {})
      };
    });
    const filledRun = widgetStyle === "filled" && grouping === "merged";
    const named = name => ({
          "name": name,
          "color": Theme.resolveColor(name)
        });
    const picks = BarAutoColors.assign(fields, {
      "accents": Theme.baseColorNames.slice(8).map(named),
      "neutrals": Theme.baseColorNames.slice(1, 5).map(named),
      "warning": named("warning"),
      "critical": named("error"),
      "backdrop": filledRun ? Theme.resolveColor(groupColor) : Theme.background,
      // A fill need only show on the bar; otherwise the color is text or a stroke
      "minContrast": widgetStyle === "filled" && !filledRun ? 1.3 : 3
    });
    const result = Object.assign({}, widgets);
    shown.forEach((entry, n) => {
      if (Object.keys(picks[n]).length === 0)
        return;
      if (result[entry.section] === widgets[entry.section])
        result[entry.section] = widgets[entry.section].slice();
      result[entry.section][entry.index] = Object.assign({}, entry.widget, {
        "properties": Object.assign({}, entry.widget.properties, picks[n])
      });
    });
    return result;
  }

  // The bar's sections, start to end
  readonly property var sectionNames: ["left", "leftCenter", "center", "rightCenter", "right"]
  // Each widget type's Auto color fields: { type: { key: role } }
  readonly property var autoColorFields: (ConfigManager.configSchema?.definitions?.BarWidget?.oneOf ?? []).reduce((result, refObj) => {
    const def = ConfigManager.configSchema.definitions[refObj.$ref.replace("#/definitions/", "")];
    const properties = def?.properties?.properties?.properties ?? {};
    result[def?.properties?.type?.const] = Object.keys(properties).filter(key => properties[key]["x-autoColor"]).reduce((roles, key) => {
      roles[key] = properties[key]["x-autoColor"];
      return roles;
    }, {});
    return result;
  }, {})

  // BarWidgetStyle's `style` for a bar, its colors resolved
  function _widgetStyle(barConfig, merged) {
    return {
      "fill": barConfig.widgetStyle,
      "barText": Theme.foreground,
      "override": barConfig.widgetTextColor ? Theme.resolveColor(barConfig.widgetTextColor) : null,
      "tint": barConfig.tintOpacity,
      "group": merged ? Theme.resolveColor(barConfig.groupColor) : null
    };
  }

  // What a shadow is drawn in: `shadow`/`shadowColor` as a bar's look or
  // the BarStyle section has them. Automatic is black for a shadow, the
  // accent for a glow.
  function shadowColor(look) {
    if (look.shadowColor)
      return Theme.resolveColor(look.shadowColor);
    return look.shadow === "glow" ? Theme.accent : Qt.alpha("black", 0.6);
  }

  // How much less than its extent a bar reserves, given Hyprland's
  // gaps_out on its edge. A transparent bar has no inner edge to see:
  // windows start where it would be, so the gap from the widgets to them
  // (padding + gaps_out, taken off here) matches the gap to the screen
  // edge. A floating bar's islands keep the same gap to the windows as to
  // the border: its float gap in all, gaps_out included.
  function reserveTrim(barConfig, gapsOut) {
    if (barConfig.background === "transparent")
      return gapsOut;
    return barConfig.island ? gapsOut - barConfig.floatGap : 0;
  }

  // A bar's look groups (its override flag and the fields it covers, the
  // flag's `x-group` in the Bar definition): each is the BarStyle
  // section's unless the bar overrides it
  readonly property var lookGroups: ["overrideWidgetStyle", "overrideAccents", "overrideShadow"].map(flag => ({
        "flag": flag,
        "keys": Bar.fieldGroups.find(group => group.keys.includes(flag)).keys.filter(key => key !== flag)
      }))

  // A bar entry with its look filled from BarStyle where it doesn't
  // override it
  function lookOf(barConfig) {
    const look = Object.assign({}, barConfig);
    Bar.lookGroups.forEach(group => {
      if (!barConfig[group.flag])
        group.keys.forEach(key => look[key] = BarStyle.values[key]);
    });
    return look;
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
