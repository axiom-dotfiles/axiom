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
   *   shadow   { size, power, color ("rrggbbaa", or "" for the
   *            compositor's own), rgb ("rrggbb" or ""), alpha (0–1:
   *            baseAlpha × strength, capped), baseAlpha, strength,
   *            offset (px downward), soft (standing in for axiom's own
   *            blurred shadow) }, or null
   *   dim      { strength } in percent, or null
   *   opacity  { active, inactive, fullscreen } in percent, or null
   * `opts`: { activeHex, inactiveHex, borderWidth, radius, surfacesBlur,
   * shadow ({ size, color ("rrggbb" or ""), alpha (0–1), offset, soft,
   * strength (× the alpha; 1 when left out) }, or
   * null for none: axiom's own casting none) }
   */
  // The relative luminance (0–1) of "rrggbb"
  function luminance(hex) {
    const linear = i => {
      const c = parseInt(String(hex).substr(i, 2), 16) / 255;
      return c <= 0.04045 ? c / 12.92 : Math.pow((c + 0.055) / 1.055, 2.4);
    };
    return /^[0-9a-fA-F]{6}/.test(hex) ? 0.2126 * linear(0) + 0.7152 * linear(2) + 0.0722 * linear(4) : 0;
  }

  // 0–1 as two hex digits ("99")
  function alphaHex(alpha) {
    return Math.round(Math.max(0, Math.min(1, alpha)) * 255).toString(16).padStart(2, "0");
  }

  function look(values, opts) {
    const cast = values.shadow ? opts.shadow : null;
    const clamp = a => Math.max(0, Math.min(1, a));
    const strength = cast ? Math.max(0, cast.strength ?? 1) : 1;
    const alpha = cast ? clamp(cast.alpha * strength) : 0;
    const shadow = cast ? {
      "size": cast.size,
      "power": values.shadowPower,
      "color": cast.color !== "" ? cast.color + alphaHex(alpha) : "",
      "rgb": cast.color,
      "alpha": alpha,
      "baseAlpha": clamp(cast.alpha),
      "strength": strength,
      "offset": cast.offset,
      "soft": cast.soft === true
    } : null;
    return {
      "parts": lookPartNames.filter(part => part === "shadow" ? shadow !== null : values[part]),
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
      "shadow": shadow,
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

  // The session's environment ([{ name, value }], each name once, every
  // backend's): the recommended one when `session.recommendedEnv`, the
  // cursor's (`cursor`: { theme, size } or null), then the session's own,
  // which win over both. A name that isn't a variable's is left out.
  function sessionEnv(session, cursor) {
    const pairs = (session?.recommendedEnv ? root.recommendedEnv : []).concat(cursor ? [["XCURSOR_THEME", cursor.theme], ["XCURSOR_SIZE", String(cursor.size)]] : []);
    const all = pairs.map(([name, value]) => ({
          "name": name,
          "value": value
        })).concat((session?.env ?? []).map(entry => ({
          "name": String(entry.name ?? "").trim(),
          "value": String(entry.value ?? "")
        }))).filter(entry => /^[A-Za-z_][A-Za-z0-9_]*$/.test(entry.name));
    return all.filter((entry, i) => !all.slice(i + 1).some(later => later.name === entry.name));
  }
}
