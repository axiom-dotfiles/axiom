pragma Singleton
import QtQuick

// The greeter's config, both ways (GreeterManager writes it, ConfigManager
// reads it in the greeter). The greeter runs as another user, who can't
// read the user's config, so the user's axiom exports the part of it the
// greeter shows (the bundle, a partial config: the greeter fills the rest
// with schema defaults) to a folder it can read. Only data crosses: the
// greeter's own code turns it into anything it runs.
QtObject {
  id: root

  // The sections exported whole (Lockscreen for its blurWallpaper, which
  // the greeter follows too)
  readonly property var sections: ["Greeter", "Appearance", "General", "Weather", "Lockscreen"]

  // The bundle for `config`: its sections, the wallpapers renamed through
  // `wallpaperUrls` ({ the user's url: the bundle's copy }; a wallpaper
  // without a copy is left out, and the background falls back to its
  // color), the monitor layouts, and in managed mode the Hyprland options
  // marked x-greeter (`managedSchema`: Hyprland.managed's schema)
  function exportConfig(config, managedSchema, wallpaperUrls) {
    const out = {
      "version": config.version
    };
    for (const section of root.sections)
      if (config[section] !== undefined)
        out[section] = JSON.parse(JSON.stringify(config[section]));
    const appearance = out.Appearance;
    if (appearance) {
      const copy = url => wallpaperUrls?.[url] ?? "";
      appearance.wallpaper = copy(appearance.wallpaper);
      const wallpapers = {};
      for (const monitor in appearance.wallpapers ?? {}) {
        const url = copy(appearance.wallpapers[monitor]);
        if (url)
          wallpapers[monitor] = url;
      }
      appearance.wallpapers = wallpapers;
    }
    const hyprland = config.Hyprland ?? {};
    out.Hyprland = {
      "mode": hyprland.mode,
      "monitors": {
        "profiles": JSON.parse(JSON.stringify(hyprland.monitors?.profiles ?? []))
      }
    };
    if (hyprland.mode === "managed")
      out.Hyprland.managed = root.greeterOptions(managedSchema, hyprland.managed);
    return out;
  }

  // The x-greeter options of `managed` (Hyprland.managed's values)
  function greeterOptions(managedSchema, managed) {
    const props = managedSchema?.properties ?? {};
    const out = {};
    for (const key in props)
      if (props[key]["x-greeter"] === true && managed?.[key] !== undefined)
        out[key] = JSON.parse(JSON.stringify(managed[key]));
    return out;
  }

  // The wallpapers the bundle needs copies of: every url `config` uses
  function wallpaperSources(config) {
    const appearance = config?.Appearance ?? {};
    const urls = [appearance.wallpaper].concat(Object.keys(appearance.wallpapers ?? {}).map(monitor => appearance.wallpapers[monitor]));
    return urls.filter((url, i) => !!url && urls.indexOf(url) === i);
  }

  // Which config the greeter runs: the first of `candidates` ({ source,
  // text }, in order: the bundle, the install's snapshot) that parses and
  // that `prepare(raw)` accepts (ConfigManager's migrate, prune, defaults
  // and validate: { config, errors }), else the schema's defaults
  // (`fallback`, from prepare({})). A bundle newer than the greeter's code
  // is still tried: its unknown keys are pruned, and only what breaks
  // validation makes it fall through.
  // { source ("bundle" | "fallback" | "defaults"), config, problems:
  // [{ source, error }] }
  function pick(candidates, prepare, defaults) {
    const problems = [];
    for (const candidate of candidates ?? []) {
      if (!candidate.text) {
        problems.push({
          "source": candidate.source,
          "error": "missing"
        });
        continue;
      }
      let raw;
      try {
        raw = JSON.parse(candidate.text);
      } catch (e) {
        problems.push({
          "source": candidate.source,
          "error": "not JSON: " + e.message
        });
        continue;
      }
      const prepared = prepare(raw);
      if (prepared.errors.length === 0)
        return {
          "source": candidate.source,
          "config": prepared.config,
          "problems": problems
        };
      problems.push({
        "source": candidate.source,
        "error": prepared.errors.join("; ")
      });
    }
    return {
      "source": "defaults",
      "config": defaults(),
      "problems": problems
    };
  }
}
