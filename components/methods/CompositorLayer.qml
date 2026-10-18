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

  /**
   * A compositor shadow that's a gaussian of sigma radius / 2 (SwayFX's,
   * niri's: their softness is a blur radius) standing in for axiom's own
   * (a soft one: MultiEffect's blur; look()'s shadow, its baseAlpha
   * axiom's and its strength the user's), as { radius, alpha }. It reaches
   * about twice as far as axiom's at the same size. Fitted against axiom's
   * glow (MultiEffect, sizes 8–64, scenefx 0.5's box_shadow.frag; within
   * ~0.02 rms): the radius 0.7 × axiom's size, the alpha axiom's × 0.2
   * ln(size), more as it grows.
   */
  function gaussianShadow(shadow) {
    const size = Math.max(2, shadow.size);
    return {
      "radius": Math.round(size * 0.7),
      // Strength scales what's fitted, which then has room to grow
      "alpha": Math.min(1, shadow.baseAlpha * Math.min(1, 0.2 * Math.log(size)) * (shadow.strength ?? 1))
    };
  }

  readonly property var inputPartNames: ["keyboard", "mouse", "touchpad", "cursor"]

  /**
   * The input (Input's values) as the parts that are on:
   *   parts    the names of the parts on, in inputPartNames' order
   *   values   Input's values, for a backend mapping fields by their schema
   *            annotations (x-hypr, gated by x-hyprIf on their part)
   *   cursor   { theme, size, xcursor } while the cursor part is on with a
   *            theme, or null. `xcursor` is the name XCursor readers get
   *            (`xcursorTheme`: CursorThemeManager's companion theme
   *            filling in the standard names the theme lacks), else the
   *            theme's
   */
  function input(values, xcursorTheme) {
    return {
      "parts": inputPartNames.filter(part => values[part]),
      "values": values,
      "cursor": values.cursor && values.cursorTheme ? {
        "theme": values.cursorTheme,
        "size": values.cursorSize,
        "xcursor": xcursorTheme || values.cursorTheme
      } : null
    };
  }

  /**
   * The fields of a section (`sectionSchema`, with `values`) that carry
   * the `annotation` a backend maps fields by (x-sway, x-niri): [{ name,
   * schema, value }]. With `gated` (the input) each only when its x-hyprIf
   * part is on, else once changed from its default; without (a managed
   * config's options) every one with a value.
   */
  function annotatedFields(sectionSchema, values, annotation, gated) {
    const props = sectionSchema?.properties ?? {};
    const fields = [];
    for (const name in props) {
      const fieldSchema = props[name];
      const value = values?.[name];
      if (!fieldSchema[annotation] || value === undefined)
        continue;
      const condition = fieldSchema["x-hyprIf"];
      if (gated && (condition ? !values[condition] : value === fieldSchema.default))
        continue;
      fields.push({
        "name": name,
        "schema": fieldSchema,
        "value": value
      });
    }
    return fields;
  }

  // The variables Hyprland's wiki recommends, good on any Wayland
  // compositor ([name, value]; Session.recommendedEnv): toolkits on
  // Wayland first (falling back to X11 where they can), Qt scaled by pixel
  // density and without decorations of its own. Not SDL_VIDEODRIVER, which
  // breaks games bundling an older SDL.
  readonly property var recommendedEnv: [["GDK_BACKEND", "wayland,x11,*"], ["QT_QPA_PLATFORM", "wayland;xcb"], ["CLUTTER_BACKEND", "wayland"], ["ELECTRON_OZONE_PLATFORM_HINT", "auto"], ["QT_AUTO_SCREEN_SCALE_FACTOR", "1"], ["QT_WAYLAND_DISABLE_WINDOWDECORATION", "1"]]

  // The theme integrations' variables ([name, value]; `integrations`: the
  // ThemeIntegrations switches): the Qt one loads qt5ct / qt6ct, whose
  // palette is axiom's (qt6ct's plugin answers to "qt5ct" too, so one
  // value covers Qt 5 and Qt 6 apps)
  function integrationEnv(integrations) {
    return integrations?.qt ? [["QT_QPA_PLATFORMTHEME", "qt5ct"]] : [];
  }

  // The session's environment ([{ name, value }], each name once, every
  // backend's): the recommended one when `session.recommendedEnv`, the
  // theme integrations' (integrationEnv), the cursor's (`cursor`:
  // input()'s, or null), then the session's own, which win over all of
  // them. A name that isn't a variable's is left out.
  function sessionEnv(session, cursor, integrations) {
    const pairs = (session?.recommendedEnv ? root.recommendedEnv : []).concat(root.integrationEnv(integrations)).concat(cursor ? [["XCURSOR_THEME", cursor.xcursor ?? cursor.theme], ["XCURSOR_SIZE", String(cursor.size)]] : []);
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
