pragma Singleton
import QtQuick

// What axiom asks of the compositor, decided once in a neutral shape that
// every backend's config writer turns into its own text (Hyprland's Lua,
// sway's commands). Everything read from config, the theme and the shell's
// look comes in as arguments (docs/dev/compositor/contract.md).
QtObject {
  id: root

  // A color ({ r, g, b } in 0-1) as "rrggbb"
  function hex(color) {
    return [color.r, color.g, color.b].map(v => Math.round(v * 255).toString(16).padStart(2, "0")).join("");
  }

  readonly property var lookPartNames: ["borders", "shape", "gaps", "blur", "opacity"]

  /**
   * The window look (WindowLook's values) as the parts that are on:
   *   parts    the names of the parts on, in lookPartNames' order
   *   values   WindowLook's values, for a backend mapping fields by their
   *            schema annotations (x-hypr)
   *   borders  { active, inactive } ("rrggbb"), or null
   *   shape    { width, radius }, or null
   *   gaps     { inner, outer }, or null
   *   blur     { windows, surfaces }: whether windows blur, and whether
   *            axiom's translucent surfaces do (the compositor's blur stays
   *            on for them), or null
   *   opacity  { active, inactive, fullscreen } in percent, or null
   * `opts`: { activeHex, inactiveHex, borderWidth, radius, surfacesBlur }
   */
  function look(values, opts) {
    return {
      "parts": lookPartNames.filter(part => values[part]),
      "values": values,
      "borders": values.borders ? {
        "active": opts.activeHex,
        "inactive": opts.inactiveHex
      } : null,
      "shape": values.shape ? {
        "width": opts.borderWidth,
        "radius": opts.radius
      } : null,
      "gaps": values.gaps ? {
        "inner": values.gapsIn,
        "outer": values.gapsOut
      } : null,
      "blur": values.blur ? {
        "windows": values.windowBlur === true,
        "surfaces": opts.surfacesBlur === true
      } : null,
      "opacity": values.opacity ? {
        "active": values.activeOpacity,
        "inactive": values.inactiveOpacity,
        "fullscreen": values.fullscreenOpacity
      } : null
    };
  }

  readonly property var inputPartNames: ["keyboard", "mouse", "touchpad", "cursor"]

  /**
   * The input (Input's values) as the parts that are on:
   *   parts    the names of the parts on, in inputPartNames' order
   *   values   Input's values, for a backend mapping fields by their schema
   *            annotations (x-hypr, gated by x-hyprIf on their part)
   *   cursor   { theme, size } while the cursor part is on with a theme, or
   *            null
   */
  function input(values) {
    return {
      "parts": inputPartNames.filter(part => values[part]),
      "values": values,
      "cursor": values.cursor && values.cursorTheme ? {
        "theme": values.cursorTheme,
        "size": values.cursorSize
      } : null
    };
  }
}
