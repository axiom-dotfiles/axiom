pragma Singleton
import QtQuick

/**
 * Upgrades older config.json layouts to the current one (see
 * config/json/config.schema.json). Pure functions only: ConfigManager runs
 * migrate() on load, then writes the result back once.
 *
 * When the layout changes, bump currentVersion (and the schema's version
 * default) and add a step to migrate(), like _v1ToV2.
 *
 * Secrets (chat API keys) found in a config belong in `secrets`, so they
 * never get written back into config.json.
 */
QtObject {
  id: root

  readonly property int currentVersion: 11

  /**
   * @param config  Parsed config.json (not modified)
   * @return { config, secrets, changes, migrated }
   *   secrets: { backendName: apiKey } pulled out of the old config
   *   changes: human-readable list of what was done, for the log
   */
  function migrate(config) {
    let result = JSON.parse(JSON.stringify(config ?? {}));
    const secrets = {};
    const changes = [];
    const version = result.version ?? 1;

    if (version < 2)
      result = _v1ToV2(result, changes);
    if (version < 3)
      result = _v2ToV3(result, changes);
    if (version < 4)
      result = _v3ToV4(result, changes);
    if (version < 5)
      result = _v4ToV5(result, changes);
    if (version < 6)
      result = _v5ToV6(result, changes);
    if (version < 7)
      result = _v6ToV7(result, changes);
    if (version < 8)
      result = _v7ToV8(result, changes);
    if (version < 9)
      result = _v8ToV9(result, changes);
    if (version < 10)
      result = _v9ToV10(result, changes);
    if (version < 11)
      result = _v10ToV11(result, changes);
    result.version = Math.max(version, root.currentVersion);

    return {
      config: result,
      secrets: secrets,
      changes: changes,
      migrated: version < root.currentVersion
    };
  }

  // v2 added a standard "Workspaces" bar widget; until then that name was
  // the 5x5 grid, now "WorkspaceGrid"
  function _v1ToV2(config, changes) {
    (config.Bars ?? []).forEach((bar, barIndex) => {
      const widgets = bar?.widgets ?? {};
      Object.keys(widgets).forEach(section => {
        (widgets[section] ?? []).forEach(widget => {
          if (widget?.type !== "Workspaces")
            return;
          widget.type = "WorkspaceGrid";
          changes.push(`Bars[${barIndex}].widgets.${section}: Workspaces -> WorkspaceGrid`);
        });
      });
    });
    return config;
  }

  // v3 sizes bar widgets from their bar (extent minus 2 * inset) instead of
  // Widget.height; each bar's inset keeps its widgets the size they were
  function _v2ToV3(config, changes) {
    const widgetHeight = config.Widget?.height ?? 30;
    (config.Bars ?? []).forEach((bar, barIndex) => {
      if (!bar || bar.inset !== undefined)
        return;
      bar.inset = Math.max(0, Math.floor(((bar.extent ?? 30) - widgetHeight) / 2));
      changes.push(`Bars[${barIndex}].inset = ${bar.inset}`);
    });
    return config;
  }

  // v4 lists a dark/light pair as one theme with a light mode switch, so
  // the setting that allowed switching between them is gone
  function _v3ToV4(config, changes) {
    if (config.Appearance?.autoThemeSwitch !== undefined) {
      delete config.Appearance.autoThemeSwitch;
      changes.push("Appearance.autoThemeSwitch removed");
    }
    return config;
  }

  // v5 made Settings a view type of its own instead of a module: a Custom
  // view holding nothing but Settings becomes one, and Settings modules
  // anywhere else are dropped (an empty slot is a gap), keeping one page
  function _v4ToV5(config, changes) {
    const views = config.Overlay?.views;
    if (!Array.isArray(views))
      return config;
    const slotsOf = view => [].concat(...(view?.columns ?? []).map(column => (column?.cells ?? []).map(cell => cell?.slots ?? {})));
    const isSettings = module => module?.type === "Settings";
    let converted = false;
    let dropped = false;
    views.forEach((view, viewIndex) => {
      if (view?.type !== "Custom")
        return;
      const modules = [].concat(...slotsOf(view).map(slots => Object.keys(slots).map(key => slots[key])));
      if (modules.length > 0 && modules.every(isSettings)) {
        views[viewIndex] = view.visible === undefined ? {
          "type": "Settings"
        } : {
          "type": "Settings",
          "visible": view.visible
        };
        converted = true;
        changes.push(`Overlay.views[${viewIndex}]: Custom Settings view -> Settings view`);
        return;
      }
      slotsOf(view).forEach(slots => Object.keys(slots).forEach(key => {
          if (!isSettings(slots[key]))
            return;
          delete slots[key];
          dropped = true;
          changes.push(`Overlay.views[${viewIndex}]: Settings module removed`);
        }));
    });
    if (dropped && !converted) {
      views.push({
        "type": "Settings"
      });
      changes.push("Overlay.views: Settings view added");
    }
    return config;
  }

  // v6 split General.monitors "all" (every monitor, opening on the focused
  // one) into "focused" (that) and "all" (open on every monitor at once)
  function _v5ToV6(config, changes) {
    if (config.General?.monitors === "all") {
      config.General.monitors = "focused";
      changes.push("General.monitors: all -> focused");
    }
    return config;
  }

  // v7 made Themes a view type instead of a page pinned before the overlay
  // editor, so a config without one gets it last, where it used to be
  function _v6ToV7(config, changes) {
    const views = config.Overlay?.views;
    if (!Array.isArray(views) || views.some(view => view?.type === "Themes"))
      return config;
    views.push({
      "type": "Themes"
    });
    changes.push("Overlay.views: Themes view added");
    return config;
  }

  // v8 moved the workspace layout into its own Workspaces section: the
  // WorkspaceGrid bar widget became the Workspaces widget in a 5×5 grid
  // layout, and the widgets' and WorkspacesMap modules' `count` became
  // Workspaces.count
  function _v7ToV8(config, changes) {
    const workspaces = config.Workspaces ?? {};
    let grid = false;
    let count;
    (config.Bars ?? []).forEach((bar, barIndex) => {
      const widgets = bar?.widgets ?? {};
      Object.keys(widgets).forEach(section => {
        (widgets[section] ?? []).forEach(widget => {
          const where = `Bars[${barIndex}].widgets.${section}`;
          if (widget?.type === "WorkspaceGrid") {
            widget.type = "Workspaces";
            grid = true;
            const props = widget.properties;
            if (props?.iconColor !== undefined) {
              props.textColor = props.iconColor;
              delete props.iconColor;
            }
            changes.push(`${where}: WorkspaceGrid -> Workspaces`);
          } else if (widget?.type === "Workspaces" && widget.properties?.count !== undefined) {
            count = count ?? widget.properties.count;
            delete widget.properties.count;
            changes.push(`${where}: Workspaces count moved to Workspaces.count`);
          }
        });
      });
    });
    (config.Overlay?.views ?? []).forEach((view, viewIndex) => {
      (view?.columns ?? []).forEach(column => (column?.cells ?? []).forEach(cell => {
          const slots = cell?.slots ?? {};
          Object.keys(slots).forEach(key => {
            const module = slots[key];
            if (module?.type !== "WorkspacesMap" || module.properties?.count === undefined)
              return;
            count = count ?? module.properties.count;
            delete module.properties.count;
            changes.push(`Overlay.views[${viewIndex}]: WorkspacesMap count moved to Workspaces.count`);
          });
        }));
    });
    if (grid && workspaces.layout === undefined) {
      workspaces.layout = "grid";
      changes.push("Workspaces.layout = grid");
    }
    if (count !== undefined && workspaces.count === undefined) {
      workspaces.count = count;
      changes.push(`Workspaces.count = ${count}`);
    }
    if (Object.keys(workspaces).length > 0)
      config.Workspaces = workspaces;
    return config;
  }

  // v9 moved icons from Nerd Font glyphs to Material Symbols names. Icon
  // fields that still hold one of the old default glyphs get its name;
  // anything else a user typed still draws, in the text font
  readonly property var _v9Icons: ({
      "\u{F08C7}": "apps",
      "\u{EB94}": "menu",
      "\u{F001}": "music_note"
    })

  function _v8ToV9(config, changes) {
    const convert = (holder, where) => {
      if (typeof holder?.icon !== "string")
        return;
      const icon = holder.icon.trim();
      const name = root._v9Icons[icon] ?? icon;
      if (name === holder.icon)
        return;
      holder.icon = name;
      changes.push(`${where}.icon -> ${JSON.stringify(name)}`);
    };
    (config.Bars ?? []).forEach((bar, barIndex) => {
      const widgets = bar?.widgets ?? {};
      Object.keys(widgets).forEach(section => {
        (widgets[section] ?? []).forEach((widget, index) => {
          if (widget?.type === "Button" || widget?.type === "Window")
            convert(widget.properties, `Bars[${barIndex}].widgets.${section}[${index}]`);
        });
      });
    });
    (config.OSD?.apps ?? []).forEach((app, index) => convert(app, `OSD.apps[${index}]`));
    return config;
  }

  // v10 dropped Popouts.workspaceIcons: the grid popout follows its
  // Workspaces widget's showAppIcons, which did nothing in a grid until
  // now, so a grid that had popout icons (the old default) turns it on.
  function _v9ToV10(config, changes) {
    if (!config.Popouts || !("workspaceIcons" in config.Popouts))
      return config;
    const icons = config.Popouts.workspaceIcons !== false;
    delete config.Popouts.workspaceIcons;
    changes.push("Popouts.workspaceIcons removed");
    if (!icons || config.Workspaces?.layout !== "grid")
      return config;
    (config.Bars ?? []).forEach((bar, barIndex) => {
      const widgets = bar?.widgets ?? {};
      Object.keys(widgets).forEach(section => {
        (widgets[section] ?? []).forEach((widget, index) => {
          if (widget?.type !== "Workspaces" || widget.properties?.showAppIcons === true)
            return;
          widget.properties = widget.properties ?? {};
          widget.properties.showAppIcons = true;
          changes.push(`Bars[${barIndex}].widgets.${section}[${index}].properties.showAppIcons -> true`);
        });
      });
    });
    return config;
  }

  // v11 rebuilt the chat: Chat.backends ({ name: { defaultModel, models } })
  // became Chat.providers, a list with each provider's API kind and
  // address; `enabled` went (a Chat module on a page is what enables it)
  // and defaultBackend became defaultProvider. The old default models are
  // retired; any a user added are kept on their provider.
  readonly property var _v11OldModels: ["gemini-2.5-pro", "gemini-2.5-flash", "gpt-4o", "gpt-4o-mini", "claude-sonnet-4-20250514"]
  readonly property var _v11Providers: [
    {
      "id": "anthropic",
      "name": "Anthropic",
      "kind": "anthropic",
      "baseUrl": "https://api.anthropic.com/v1",
      "auth": "key",
      "keyEnv": "ANTHROPIC_API_KEY",
      "models": ["claude-opus-5", "claude-sonnet-5", "claude-haiku-4-5", "claude-fable-5-1", "claude-opus-5-5"],
      "defaultModel": "claude-opus-5",
      "fallbacks": true
    },
    {
      "id": "openai",
      "name": "OpenAI",
      "kind": "openai",
      "baseUrl": "https://api.openai.com/v1",
      "auth": "key",
      "keyEnv": "OPENAI_API_KEY",
      "models": ["gpt-5", "gpt-5-mini"],
      "defaultModel": "gpt-5",
      "fallbacks": false
    },
    {
      "id": "gemini",
      "name": "Gemini",
      "kind": "gemini",
      "baseUrl": "https://generativelanguage.googleapis.com/v1beta",
      "auth": "key",
      "keyEnv": "GEMINI_API_KEY",
      "models": ["gemini-2.5-pro", "gemini-2.5-flash"],
      "defaultModel": "gemini-2.5-flash",
      "fallbacks": false
    },
    {
      "id": "ollama",
      "name": "Ollama",
      "kind": "openai",
      "baseUrl": "http://localhost:11434/v1",
      "auth": "none",
      "keyEnv": "",
      "models": [],
      "defaultModel": "",
      "fallbacks": false
    }
  ]

  function _v10ToV11(config, changes) {
    const chat = config.Chat;
    if (!chat)
      return config;
    if ("enabled" in chat) {
      delete chat.enabled;
      changes.push("Chat.enabled removed");
    }
    if ("defaultBackend" in chat) {
      if (chat.defaultProvider === undefined)
        chat.defaultProvider = chat.defaultBackend;
      delete chat.defaultBackend;
      changes.push(`Chat.defaultBackend -> Chat.defaultProvider (${chat.defaultProvider})`);
    }
    const backends = chat.backends;
    delete chat.backends;
    if (!backends || typeof backends !== "object" || chat.providers !== undefined)
      return config;
    changes.push("Chat.backends -> Chat.providers");
    const added = {};
    Object.keys(backends).forEach(name => {
      const extra = (backends[name]?.models ?? []).filter(model => !root._v11OldModels.includes(model));
      if (extra.length > 0)
        added[name] = extra;
    });
    // Nothing of the user's own: the schema's providers fill in
    if (Object.keys(added).length === 0)
      return config;
    chat.providers = JSON.parse(JSON.stringify(root._v11Providers));
    Object.keys(added).forEach(name => {
      const provider = chat.providers.find(p => p.id === name);
      if (!provider)
        return;
      provider.models = provider.models.concat(added[name].filter(model => !provider.models.includes(model)));
      changes.push(`Chat.providers.${name}: kept ${added[name].join(", ")}`);
    });
    return config;
  }
}
