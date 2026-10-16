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

  readonly property var lookPartNames: ["borders", "shape", "gaps", "blur", "shadow", "dim", "opacity"]

  /**
   * The window look (WindowLook's values) as the parts that are on:
   *   parts    the names of the parts on, in lookPartNames' order
   *   values   WindowLook's values, for a backend mapping fields by their
   *            schema annotations (x-hypr)
   *   borders  { active, inactive } ("rrggbb"), or null
   *   shape    { width, radius }, or null
   *   gaps     { inner, outer }, or null
   *   blur     { windows, surfaces, size, passes, xray, noise, contrast }:
   *            whether windows blur, and whether axiom's translucent
   *            surfaces do (the compositor's blur stays on for them), and
   *            its strength (noise in ‰, contrast in %), or null
   *   shadow   { size, power, color ("rrggbb", or "" for the compositor's
   *            own) }, or null
   *   dim      { strength } in percent, or null
   *   opacity  { active, inactive, fullscreen } in percent, or null
   * `opts`: { activeHex, inactiveHex, borderWidth, radius, surfacesBlur,
   * shadowHex }
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
        "surfaces": opts.surfacesBlur === true,
        "size": values.blurSize,
        "passes": values.blurPasses,
        "xray": values.blurXray === true,
        "noise": values.blurNoise,
        "contrast": values.blurContrast
      } : null,
      "shadow": values.shadow ? {
        "size": values.shadowSize,
        "power": values.shadowPower,
        "color": opts.shadowHex ?? ""
      } : null,
      "dim": values.dim ? {
        "strength": values.dimStrength
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

  // The variables Hyprland's wiki recommends, good on any Wayland
  // compositor ([name, value]; Session.recommendedEnv): toolkits on
  // Wayland first (falling back to X11 where they can), Qt scaled by pixel
  // density and without decorations of its own. Not SDL_VIDEODRIVER, which
  // breaks games bundling an older SDL.
  readonly property var recommendedEnv: [["GDK_BACKEND", "wayland,x11,*"], ["QT_QPA_PLATFORM", "wayland;xcb"], ["CLUTTER_BACKEND", "wayland"], ["ELECTRON_OZONE_PLATFORM_HINT", "auto"], ["QT_AUTO_SCREEN_SCALE_FACTOR", "1"], ["QT_WAYLAND_DISABLE_WINDOWDECORATION", "1"]]

  // The session's environment ([{ name, value }]): the recommended one
  // when `session.recommendedEnv`, the cursor's (`cursor`: { theme, size }
  // or null), then the session's own, which win over both
  function sessionEnv(session, cursor) {
    const pairs = (session?.recommendedEnv ? root.recommendedEnv : []).concat(cursor ? [["XCURSOR_THEME", cursor.theme], ["XCURSOR_SIZE", String(cursor.size)]] : []);
    return pairs.map(([name, value]) => ({
          "name": name,
          "value": value
        })).concat(session?.env ?? []);
  }
}
