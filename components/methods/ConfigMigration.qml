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

  readonly property int currentVersion: 48

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
    if (version < 12)
      result = _v11ToV12(result, changes);
    if (version < 13)
      result = _v12ToV13(result, changes);
    if (version < 14)
      result = _v13ToV14(result, changes);
    if (version < 15)
      result = _v14ToV15(result, changes);
    if (version < 16)
      result = _v15ToV16(result, changes);
    if (version < 17)
      result = _v16ToV17(result, changes);
    if (version < 18)
      result = _v17ToV18(result, changes);
    if (version < 19)
      result = _v18ToV19(result, changes);
    if (version < 20)
      result = _v19ToV20(result, changes);
    if (version < 21)
      result = _v20ToV21(result, changes);
    if (version < 22)
      result = _v21ToV22(result, changes);
    if (version < 23)
      result = _v22ToV23(result, changes);
    if (version < 24)
      result = _v23ToV24(result, changes);
    if (version < 25)
      result = _v24ToV25(result, changes);
    if (version < 26)
      result = _v25ToV26(result, changes);
    if (version < 27)
      result = _v26ToV27(result, changes);
    if (version < 28)
      result = _v27ToV28(result, changes);
    if (version < 29)
      result = _v28ToV29(result, changes);
    if (version < 30)
      result = _v29ToV30(result, changes);
    if (version < 31)
      result = _v30ToV31(result, changes);
    if (version < 32)
      result = _v31ToV32(result, changes);
    if (version < 33)
      result = _v32ToV33(result, changes);
    if (version < 34)
      result = _v33ToV34(result, changes);
    if (version < 35)
      result = _v34ToV35(result, changes);
    if (version < 36)
      result = _v35ToV36(result, changes);
    if (version < 37)
      result = _v36ToV37(result, changes);
    if (version < 38)
      result = _v37ToV38(result, changes);
    if (version < 39)
      result = _v38ToV39(result, changes);
    if (version < 40)
      result = _v39ToV40(result, changes);
    if (version < 41)
      result = _v40ToV41(result, changes);
    if (version < 42)
      result = _v41ToV42(result, changes);
    if (version < 43)
      result = _v42ToV43(result, changes);
    if (version < 44)
      result = _v43ToV44(result, changes);
    if (version < 45)
      result = _v44ToV45(result, changes);
    if (version < 46)
      result = _v45ToV46(result, changes);
    if (version < 47)
      result = _v46ToV47(result, changes);
    if (version < 48)
      result = _v47ToV48(result, changes);
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

  // v12 merged the QuickToggles and Session modules into QuickActions, whose
  // one `actions` list takes toggles and session actions alike
  function _v11ToV12(config, changes) {
    const toggles = ["wifi", "bluetooth", "caffeine", "dnd", "darkMode"];
    const session = ["lock", "suspend", "hibernate", "logout", "reboot", "poweroff"];
    const convert = (columns, where) => (columns ?? []).forEach(column => (column?.cells ?? []).forEach(cell => {
          const slots = cell?.slots ?? {};
          Object.keys(slots).forEach(key => {
            const module = slots[key];
            if (module?.type !== "QuickToggles" && module?.type !== "Session")
              return;
            const props = module.properties ?? {};
            const actions = module.type === "QuickToggles" ? (props.toggles ?? toggles) : (props.actions ?? session);
            changes.push(`${where}: ${module.type} -> QuickActions`);
            module.type = "QuickActions";
            module.properties = {
              "actions": actions.slice()
            };
          });
        }));
    (config.Overlay?.views ?? []).forEach((view, index) => convert(view?.columns, `Overlay.views[${index}]`));
    (config.EdgeMenus ?? []).forEach((menu, index) => convert(menu?.columns, `EdgeMenus[${index}]`));
    return config;
  }

  // v13 made the edge menu editor an ordinary view, so a page list saved
  // without it gets it back once (the user may remove it afterwards)
  function _v12ToV13(config, changes) {
    const views = config.Overlay?.views;
    if (!Array.isArray(views) || views.some(view => view?.type === "EdgeMenuEditor"))
      return config;
    views.push({
      "type": "EdgeMenuEditor"
    });
    changes.push("Overlay.views: added the EdgeMenuEditor page");
    return config;
  }

  // v14 reads the Network widget's connection from NetworkingManager
  // (D-Bus) instead of polling nmcli, so its poll interval is gone
  function _v13ToV14(config, changes) {
    (config.Bars ?? []).forEach((bar, barIndex) => {
      const widgets = bar?.widgets ?? {};
      Object.keys(widgets).forEach(section => {
        (widgets[section] ?? []).forEach(widget => {
          if (widget?.type !== "Network" || widget.properties?.interval === undefined)
            return;
          delete widget.properties.interval;
          changes.push(`Bars[${barIndex}].widgets.${section}: removed Network.interval`);
        });
      });
    });
    return config;
  }

  // v15 gave OSD bars a type: "master" and "other" were magic app names,
  // and the microphone and brightness bars are new types
  function _v14ToV15(config, changes) {
    const apps = config.OSD?.apps;
    if (!Array.isArray(apps))
      return config;
    config.OSD.bars = apps.map(entry => {
      const bar = Object.assign({}, entry);
      const special = entry?.app === "master" || entry?.app === "other";
      bar.type = special ? entry.app : "app";
      if (special)
        delete bar.app;
      return bar;
    });
    delete config.OSD.apps;
    changes.push("OSD.apps: became OSD.bars, with a type per bar");
    return config;
  }

  // v16 split an edge menu's extraDepth (room across its edge) into
  // extraWidth and extraHeight: a left/right menu's depth is its width,
  // a top/bottom one's its height
  function _v15ToV16(config, changes) {
    (config.EdgeMenus ?? []).forEach((menu, index) => {
      if (!menu || !("extraDepth" in menu))
        return;
      const depth = menu.extraDepth;
      delete menu.extraDepth;
      const key = menu.edge === "Top" || menu.edge === "Bottom" ? "extraHeight" : "extraWidth";
      if (depth > 0 && menu[key] === undefined)
        menu[key] = depth;
      changes.push(`EdgeMenus[${index}].extraDepth -> ${key} (${depth})`);
    });
    return config;
  }

  // v17 keeps notes as Markdown files in a folder (NotesManager): a Notes
  // module's `name` (its state file, note-<name>.json, with the same
  // characters replaced) becomes the path of the file it moved to
  function _v16ToV17(config, changes) {
    const convert = (columns, where) => (columns ?? []).forEach(column => (column?.cells ?? []).forEach(cell => {
          const slots = cell?.slots ?? {};
          Object.keys(slots).forEach(key => {
            const module = slots[key];
            if (module?.type !== "Notes" || module.properties?.name === undefined)
              return;
            const name = module.properties.name;
            delete module.properties.name;
            if (name !== "")
              module.properties.note = name.replace(/[^A-Za-z0-9_-]/g, "_") + ".md";
            changes.push(`${where}: Notes.name -> note (${module.properties.note ?? "last opened"})`);
          });
        }));
    (config.Overlay?.views ?? []).forEach((view, index) => convert(view?.columns, `Overlay.views[${index}]`));
    (config.EdgeMenus ?? []).forEach((menu, index) => convert(menu?.columns, `EdgeMenus[${index}]`));
    return config;
  }

  // v18 added the Monitors page (monitor layout, Hyprland.monitors): a page
  // list saved without it gets it once, as in v13
  function _v17ToV18(config, changes) {
    const views = config.Overlay?.views;
    if (!Array.isArray(views) || views.some(view => view?.type === "Monitors"))
      return config;
    views.push({
      "type": "Monitors"
    });
    changes.push("Overlay.views: added the Monitors page");
    return config;
  }

  // v19 split a cell's `fill` into fillWidth and fillHeight: a fill cell
  // grew both ways
  function _v18ToV19(config, changes) {
    const convert = (columns, where) => (columns ?? []).forEach(column => (column?.cells ?? []).forEach(cell => {
          if (!cell || !("fill" in cell))
            return;
          const fill = cell.fill === true;
          delete cell.fill;
          if (!fill)
            return;
          cell.fillWidth = true;
          cell.fillHeight = true;
          changes.push(`${where}: a cell's fill -> fillWidth and fillHeight`);
        }));
    (config.Overlay?.views ?? []).forEach((view, index) => convert(view?.columns, `Overlay.views[${index}]`));
    (config.EdgeMenus ?? []).forEach((menu, index) => convert(menu?.columns, `EdgeMenus[${index}]`));
    return config;
  }

  // Binds v20 added to the defaults: apps, screenshots and a way out
  readonly property var _v20Binds: [
    {
      "key": "SUPER + SHIFT + Escape",
      "action": "exitHyprland",
      "release": true
    },
    {
      "key": "SUPER + Return",
      "action": "terminal"
    },
    {
      "key": "SUPER + E",
      "action": "fileManager"
    },
    {
      "key": "SUPER + B",
      "action": "browser"
    },
    {
      "key": "Print",
      "action": "screenshot",
      "argument": "region"
    },
    {
      "key": "SHIFT + Print",
      "action": "screenshot",
      "argument": "window"
    },
    {
      "key": "SUPER + Print",
      "action": "screenshot",
      "argument": "screen"
    }
  ]

  // v20 added app, screenshot and exit actions: a saved bind list gets
  // their default binds, each only on a key it doesn't use yet
  function _v19ToV20(config, changes) {
    return root._addBinds(config, changes, root._v20Binds);
  }

  // A saved bind list gets these default binds, each only on a key it
  // doesn't use yet
  function _addBinds(config, changes, added) {
    const binds = config.Hyprland?.binds;
    if (!Array.isArray(binds))
      return config;
    const used = new Set(binds.map(bind => HyprBinds.keyId(bind?.key)));
    for (const bind of added) {
      const id = HyprBinds.keyId(bind.key);
      if (used.has(id))
        continue;
      binds.push(JSON.parse(JSON.stringify(bind)));
      used.add(id);
      changes.push(`Hyprland.binds: added ${bind.key} (${bind.action})`);
    }
    return config;
  }

  // v21 sizes a bar by its widgets instead of the other way round: its
  // thickness (extent) and widget inset become the widget size (what was
  // extent minus twice the inset) and the padding around them, and the
  // thickness follows from those
  function _v20ToV21(config, changes) {
    (config.Bars ?? []).forEach((bar, barIndex) => {
      if (!bar || (bar.extent === undefined && bar.inset === undefined))
        return;
      const extent = bar.extent ?? 30;
      const inset = bar.inset ?? 0;
      bar.widgetSize = Math.min(150, Math.max(10, extent - 2 * inset));
      bar.padding = Math.min(50, inset);
      delete bar.extent;
      delete bar.inset;
      changes.push(`Bars[${barIndex}]: extent ${extent}, inset ${inset} -> widgetSize ${bar.widgetSize}, padding ${bar.padding}`);
    });
    return config;
  }

  // v22 added a second region screenshot bind, on a key a laptop has
  function _v21ToV22(config, changes) {
    return root._addBinds(config, changes, [
      {
        "key": "SUPER + CTRL + S",
        "action": "screenshot",
        "argument": "region"
      }
    ]);
  }

  // v23 moved the apps the binds open out of Launcher into their own
  // section
  function _v22ToV23(config, changes) {
    const launcher = config.Launcher;
    if (!launcher)
      return config;
    for (const key of ["terminal", "fileManager", "browser"]) {
      if (launcher[key] === undefined)
        continue;
      config.Apps = config.Apps ?? {};
      config.Apps[key] = launcher[key];
      delete launcher[key];
      changes.push(`Launcher.${key} -> Apps.${key}`);
    }
    return config;
  }

  // v24 has several OSDs: the one OSD's own settings become the first of
  // OSD.osds, and its scroll settings stay shared
  function _v23ToV24(config, changes) {
    const osd = config.OSD;
    if (!osd || osd.osds !== undefined)
      return config;
    const entry = {
      "id": "main"
    };
    for (const key of ["monitors", "edge", "position", "orientation", "alongEdge", "openOnHover", "timeout", "showPercent", "bars"]) {
      if (osd[key] === undefined)
        continue;
      entry[key] = osd[key];
      delete osd[key];
    }
    osd.osds = [entry];
    changes.push("OSD: its settings moved to OSD.osds[0]");
    return config;
  }

  // v25 has one popout padding (Popouts.padding): an edge menu still at the
  // old default of 12 follows it (-1) instead of keeping its own
  function _v24ToV25(config, changes) {
    for (const menu of config.EdgeMenus ?? []) {
      if (menu?.padding !== 12)
        continue;
      menu.padding = -1;
      changes.push(`EdgeMenus[${menu.id}].padding: 12 -> -1 (follows Popouts.padding)`);
    }
    return config;
  }

  // v26 generates themes in styles instead of one pair per pywal backend:
  // a pywal pair becomes the tonal pair (ThemeManager regenerates it, since
  // the file isn't there yet)
  function _v25ToV26(config, changes) {
    const theme = config.Appearance?.theme;
    const match = /^generated\/pywal-(dark|light)(-\w+)?$/.exec(theme ?? "");
    if (!match)
      return config;
    config.Appearance.theme = `generated/wallpaper-tonal-${match[1]}`;
    changes.push(`Appearance.theme: ${theme} -> ${config.Appearance.theme}`);
    return config;
  }

  // v27 gave each bar its own widget padding and inner spacing, which came
  // from the global Widget section before; bars keep the values they had
  function _v26ToV27(config, changes) {
    (config.Bars ?? []).forEach((bar, barIndex) => {
      if (bar.widgetPadding === undefined && config.Widget?.padding !== undefined) {
        bar.widgetPadding = config.Widget.padding;
        changes.push(`Bars[${barIndex}].widgetPadding = Widget.padding (${bar.widgetPadding})`);
      }
      if (bar.widgetSpacing === undefined && config.Widget?.spacing !== undefined) {
        bar.widgetSpacing = config.Widget.spacing;
        changes.push(`Bars[${barIndex}].widgetSpacing = Widget.spacing (${bar.widgetSpacing})`);
      }
    });
    return config;
  }

  // Binds v28 added to the defaults: WASD steps through workspaces (around
  // the grid in a grid layout, previous and next otherwise)
  readonly property var _v28Binds: [
    {
      "key": "SUPER + W",
      "action": "workspaceStep",
      "argument": "up"
    },
    {
      "key": "SUPER + SHIFT + W",
      "action": "moveWindowStep",
      "argument": "up"
    },
    {
      "key": "SUPER + A",
      "action": "workspaceStep",
      "argument": "left"
    },
    {
      "key": "SUPER + SHIFT + A",
      "action": "moveWindowStep",
      "argument": "left"
    },
    {
      "key": "SUPER + S",
      "action": "workspaceStep",
      "argument": "down"
    },
    {
      "key": "SUPER + SHIFT + S",
      "action": "moveWindowStep",
      "argument": "down"
    },
    {
      "key": "SUPER + D",
      "action": "workspaceStep",
      "argument": "right"
    },
    {
      "key": "SUPER + SHIFT + D",
      "action": "moveWindowStep",
      "argument": "right"
    }
  ]

  // v28 added WASD workspace steps: a saved bind list gets them, each only
  // on a key it doesn't use yet
  function _v27ToV28(config, changes) {
    return root._addBinds(config, changes, root._v28Binds);
  }

  // v29 lets an App bar match several apps: its `app` string became an
  // `apps` list
  function _v28ToV29(config, changes) {
    (config.OSD?.osds ?? []).forEach(osd => {
      (osd?.bars ?? []).forEach((bar, index) => {
        if (!bar || !("app" in bar))
          return;
        if (bar.apps === undefined)
          bar.apps = typeof bar.app === "string" && bar.app !== "" ? [bar.app] : [];
        delete bar.app;
        changes.push(`OSD.osds[${osd.id}].bars[${index}].app -> apps`);
      });
    });
    return config;
  }

  // Every bar widget: fn(widget, where)
  function _eachWidget(config, fn) {
    (config.Bars ?? []).forEach((bar, barIndex) => {
      const widgets = bar?.widgets ?? {};
      Object.keys(widgets).forEach(section => (widgets[section] ?? []).forEach((widget, index) => {
          if (widget)
            fn(widget, `Bars[${barIndex}].widgets.${section}[${index}]`);
        }));
    });
  }

  // Every module on an overlay page or in an edge menu: fn(module, where)
  function _eachModule(config, fn) {
    const walk = (columns, where) => (columns ?? []).forEach((column, c) => (column?.cells ?? []).forEach((cell, k) => {
          const slots = cell?.slots ?? {};
          Object.keys(slots).forEach(key => {
            if (slots[key])
              fn(slots[key], `${where}.columns[${c}].cells[${k}].slots.${key}`);
          });
        }));
    (config.Overlay?.views ?? []).forEach((view, index) => walk(view?.columns, `Overlay.views[${index}]`));
    (config.EdgeMenus ?? []).forEach((menu, index) => walk(menu?.columns, `EdgeMenus[${index}]`));
  }

  // Renames a key of `object` (keeping a value already under the new name)
  function _renameKey(object, from, to, where, changes) {
    if (!object || !(from in object))
      return;
    if (!(to in object))
      object[to] = object[from];
    delete object[from];
    changes.push(`${where}: ${from} -> ${to}`);
  }

  // v30 moved the battery levels and notifications from the Battery widget
  // to a Battery section (the first widget's settings carry over), and
  // evened out names: the ClaudeUsage widget's warnPercent / critPercent /
  // critColor became warnThreshold / criticalThreshold / criticalColor, as
  // on the other widgets; the ClockCalendar module's use24h became
  // use24Hour, as on the Time widget; and the Privacy widget's ignoreApps,
  // a comma-separated string, became a list
  function _v29ToV30(config, changes) {
    root._eachWidget(config, (widget, where) => {
      const props = widget.properties;
      if (!props || typeof props !== "object")
        return;
      switch (widget.type) {
      case "Battery":
        ["notify", "lowThreshold", "criticalThreshold"].forEach(key => {
          if (!(key in props))
            return;
          if (typeof config.Battery !== "object" || config.Battery === null)
            config.Battery = {};
          if (config.Battery[key] === undefined) {
            config.Battery[key] = props[key];
            changes.push(`${where}.properties.${key} -> Battery.${key}`);
          } else {
            changes.push(`${where}.properties.${key}: removed (Battery.${key} is set)`);
          }
          delete props[key];
        });
        break;
      case "ClaudeUsage":
        root._renameKey(props, "warnPercent", "warnThreshold", where, changes);
        root._renameKey(props, "critPercent", "criticalThreshold", where, changes);
        root._renameKey(props, "critColor", "criticalColor", where, changes);
        break;
      case "Privacy":
        if (typeof props.ignoreApps === "string") {
          props.ignoreApps = props.ignoreApps.split(",").map(app => app.trim()).filter(app => app !== "");
          changes.push(`${where}: ignoreApps -> a list`);
        }
        break;
      }
    });
    root._eachModule(config, (module, where) => {
      if (module.type === "ClockCalendar")
        root._renameKey(module.properties, "use24h", "use24Hour", where, changes);
    });
    return config;
  }

  // The overlay cell layouts as they were up to v30: { cols, rows, slots:
  // { name: [col, row, colSpan, rowSpan] } } in half-card units
  readonly property var _v30Layouts: ({
      "Single": [2, 2,
        {
          "main": [0, 0, 2, 2]
        }
      ],
      "Tall": [2, 4,
        {
          "main": [0, 0, 2, 4]
        }
      ],
      "Wide": [4, 2,
        {
          "main": [0, 0, 4, 2]
        }
      ],
      "Large": [4, 4,
        {
          "main": [0, 0, 4, 4]
        }
      ],
      "HalfWide": [2, 1,
        {
          "main": [0, 0, 2, 1]
        }
      ],
      "HalfTall": [1, 2,
        {
          "main": [0, 0, 1, 2]
        }
      ],
      "Grid2x2": [2, 2,
        {
          "topLeft": [0, 0, 1, 1],
          "topRight": [1, 0, 1, 1],
          "bottomLeft": [0, 1, 1, 1],
          "bottomRight": [1, 1, 1, 1]
        }
      ],
      "Vert1x1": [2, 2,
        {
          "left": [0, 0, 1, 2],
          "right": [1, 0, 1, 2]
        }
      ],
      "Vert1x2": [2, 2,
        {
          "left": [0, 0, 1, 2],
          "topRight": [1, 0, 1, 1],
          "bottomRight": [1, 1, 1, 1]
        }
      ],
      "Vert2x1": [2, 2,
        {
          "topLeft": [0, 0, 1, 1],
          "bottomLeft": [0, 1, 1, 1],
          "right": [1, 0, 1, 2]
        }
      ],
      "Horiz1x1": [2, 2,
        {
          "top": [0, 0, 2, 1],
          "bottom": [0, 1, 2, 1]
        }
      ],
      "Horiz1x2": [2, 2,
        {
          "top": [0, 0, 2, 1],
          "bottomLeft": [0, 1, 1, 1],
          "bottomRight": [1, 1, 1, 1]
        }
      ],
      "Horiz2x1": [2, 2,
        {
          "topLeft": [0, 0, 1, 1],
          "topRight": [1, 0, 1, 1],
          "bottom": [0, 1, 2, 1]
        }
      ]
    })

  // Columns of cells (v30) as modules placed on one grid: the columns side
  // by side, each flowing its cells left to right and wrapping at its
  // widest, worked out in the v30 layouts' half-card units. A cell filling
  // `acrossKeys` grows to its column's width (fillWidth) or the grid's
  // height (fillHeight), and its modules on that side with it. Returns
  // { modules, pins, fillKeys }: the modules placed in quarter-card units
  // (the half units doubled: a span of 2n quarters is a span of n halves),
  // the number of Pin modules dropped and which fill keys were set.
  function _placeColumns(columns, acrossKeys) {
    const placed = [];
    const fillKeys = {};
    let pins = 0;
    let x0 = 0;
    (columns ?? []).forEach(column => {
      const cells = (column?.cells ?? []).map(cell => {
        const layout = root._v30Layouts[cell?.layout] ?? root._v30Layouts.Single;
        return {
          "cell": cell,
          "cols": layout[0],
          "rows": layout[1],
          "slots": layout[2]
        };
      });
      const width = Math.max(0, ...cells.map(c => c.cols));
      // Flow: rows of cells, each as tall as its tallest
      const rows = [];
      let x = 0;
      cells.forEach(c => {
        if (rows.length === 0 || (x > 0 && x + c.cols > width)) {
          rows.push({
            "cells": [],
            "y": 0,
            "height": 0
          });
          x = 0;
        }
        const row = rows[rows.length - 1];
        c.x = x;
        c.row = row;
        row.cells.push(c);
        row.height = Math.max(row.height, c.rows);
        x += c.cols;
      });
      let y = 0;
      rows.forEach(row => {
        row.y = y;
        y += row.height;
      });
      cells.forEach((c, i) => {
        ["fillWidth", "fillHeight"].forEach(key => {
          if (c.cell?.[key] === true)
            fillKeys[key] = true;
        });
        const last = c.row.cells[c.row.cells.length - 1] === c;
        // Room to grow: to the column's width if last in its row; to the
        // row's height (the grid's bottom is applied once all are placed)
        const growW = acrossKeys.includes("fillWidth") && c.cell?.fillWidth === true && last ? width - (c.x + c.cols) : 0;
        const fillsDown = acrossKeys.includes("fillHeight") && c.cell?.fillHeight === true;
        const slots = c.cell?.slots ?? {};
        Object.keys(slots).forEach(name => {
          const module = slots[name];
          const rect = c.slots[name];
          if (!module?.type || !rect)
            return;
          if (module.type === "Pin") {
            pins++;
            return;
          }
          const place = {
            "x": x0 + c.x + rect[0],
            "y": c.row.y + rect[1],
            "w": rect[2] + (rect[0] + rect[2] === c.cols ? growW : 0),
            "h": rect[3]
          };
          // Grows down later if it touches its cell's bottom
          const growsDown = fillsDown && rect[1] + rect[3] === c.rows;
          placed.push({
            "module": module,
            "place": place,
            "growsDown": growsDown,
            "cellBottom": c.row.y + c.rows,
            "lastRow": c.row === rows[rows.length - 1],
            "rowBottom": c.row.y + c.row.height
          });
        });
      });
      x0 += width;
    });
    const bottom = Math.max(0, ...placed.map(p => p.place.y + p.place.h));
    placed.forEach(p => {
      if (!p.growsDown)
        return;
      const to = p.lastRow ? Math.max(bottom, p.rowBottom) : p.rowBottom;
      p.place.h += to - p.cellBottom;
    });
    return {
      // w and h kept to v31's GridPlace maximum (32): a fill cell grown
      // down a tall column could reach past it
      "modules": placed.map(p => {
        const module = Object.assign({}, p.module);
        module.place = {
          "x": p.place.x * 2,
          "y": p.place.y * 2,
          "w": Math.min(32, p.place.w * 2),
          "h": Math.min(32, p.place.h * 2)
        };
        return module;
      }),
      "pins": pins,
      "fillKeys": fillKeys
    };
  }

  // v31 replaced columns → cells → slots with modules placed on a grid:
  // each module has a `place` { x, y, w, h } in quarter-card units. Custom
  // pages and edge menus get `modules` instead of `columns`. Fill cells
  // grow into the room they took; in an edge menu a cell filling along
  // the edge makes it take the whole edge (`length: "edge"`). Menus use
  // their screen's overlay card size, so their own `cardSize` and extra
  // sizes are dropped (modules are sized in units instead). Pin modules
  // became the menu's `pinButton`. The edge menu editor became part of
  // the pinned Layouts page.
  function _v30ToV31(config, changes) {
    const views = config.Overlay?.views;
    if (Array.isArray(views)) {
      for (let v = views.length - 1; v >= 0; v--) {
        const view = views[v];
        if (view?.type === "EdgeMenuEditor") {
          views.splice(v, 1);
          changes.push(`Overlay.views[${v}]: EdgeMenuEditor removed (now part of the Layouts page)`);
          continue;
        }
        if (view?.type !== "Custom" || !("columns" in view))
          continue;
        const result = root._placeColumns(view.columns, ["fillWidth", "fillHeight"]);
        view.modules = result.modules;
        delete view.columns;
        changes.push(`Overlay.views[${v}]: columns -> ${result.modules.length} placed modules`);
        if (result.pins > 0)
          changes.push(`Overlay.views[${v}]: ${result.pins} Pin module(s) removed (pinning is an edge menu's pinButton)`);
      }
    }
    (Array.isArray(config.EdgeMenus) ? config.EdgeMenus : []).forEach((menu, m) => {
      if (!menu || typeof menu !== "object")
        return;
      const where = `EdgeMenus[${m}]`;
      const vertical = menu.edge === undefined || menu.edge === "Left" || menu.edge === "Right";
      const alongKey = vertical ? "fillHeight" : "fillWidth";
      const acrossKey = vertical ? "fillWidth" : "fillHeight";
      if ("columns" in menu) {
        const result = root._placeColumns(menu.columns, [acrossKey]);
        menu.modules = result.modules;
        delete menu.columns;
        changes.push(`${where}: columns -> ${result.modules.length} placed modules`);
        if (result.fillKeys[alongKey]) {
          menu.length = "edge";
          changes.push(`${where}: a cell filling along the edge -> length "edge"`);
        }
        if (result.pins > 0) {
          menu.pinButton = true;
          changes.push(`${where}: Pin module -> pinButton`);
        }
      }
      if ("cardSize" in menu) {
        changes.push(`${where}: card size (${menu.cardSize} px) dropped: menus use the overlay's`);
        delete menu.cardSize;
      }
      ["extraWidth", "extraHeight"].forEach(key => {
        if ((menu[key] ?? 0) > 0)
          changes.push(`${where}: ${key} (${menu[key]} px) dropped`);
        delete menu[key];
      });
    });
    return config;
  }

  // v32: an edge menu's place along its edge comes from the layouts
  // editor's grid, as an anchor (start, center or end) and a whole number
  // of grid units from it, instead of a percentage; and its frame lines up
  // with the screen border instead of taking its own margin
  function _v31ToV32(config, changes) {
    (Array.isArray(config.EdgeMenus) ? config.EdgeMenus : []).forEach((menu, m) => {
      if (!menu || typeof menu !== "object")
        return;
      const where = `EdgeMenus[${m}]`;
      if ("position" in menu) {
        const position = Number(menu.position);
        menu.align = position <= 15 ? "start" : position >= 85 ? "end" : "center";
        menu.offset = 0;
        if (![0, 50, 100].includes(position))
          changes.push(`${where}: position ${menu.position}% -> align "${menu.align}" (approximate)`);
        delete menu.position;
      }
      if ("margin" in menu) {
        changes.push(`${where}: frame margin dropped: the frame follows the screen margin`);
        delete menu.margin;
      }
    });
    return config;
  }

  // v33: tool pages can't be removed, only hidden, so every one is in
  // Overlay.views; one missing was removed, so it comes back hidden. And
  // every weather widget and module shows one location, from the new
  // Weather section: the first one that set a location (else the first
  // one) gives it, with its units, and the bar widgets' shortest refresh
  // interval. Custom pages lost `stretch`: they keep their cards square
  function _v32ToV33(config, changes) {
    const views = config.Overlay?.views;
    if (Array.isArray(views)) {
      views.forEach((view, v) => {
        if (!view || typeof view !== "object" || !("stretch" in view))
          return;
        if (view.stretch === true)
          changes.push(`Overlay.views[${v}]: stretch dropped: pages keep their cards square`);
        delete view.stretch;
      });
      ["Settings", "Keybinds", "BarEditor", "Themes", "Monitors"].forEach(type => {
        if (views.some(view => view?.type === type))
          return;
        views.push({
          "type": type,
          "visible": false
        });
        changes.push(`Overlay.views: tool page ${type} added back, hidden`);
      });
    }

    // [{ where, item }] for every Weather widget and module, bars first
    const found = [];
    const collect = (list, where) => (Array.isArray(list) ? list : []).forEach((item, i) => {
        if (item?.type === "Weather")
          found.push({
            "where": `${where}[${i}]`,
            "item": item
          });
      });
    (Array.isArray(config.Bars) ? config.Bars : []).forEach((bar, b) => {
      const widgets = bar?.widgets ?? {};
      Object.keys(widgets).forEach(section => collect(widgets[section], `Bars[${b}].widgets.${section}`));
    });
    (Array.isArray(views) ? views : []).forEach((view, v) => collect(view?.modules, `Overlay.views[${v}].modules`));
    (Array.isArray(config.EdgeMenus) ? config.EdgeMenus : []).forEach((menu, m) => collect(menu?.modules, `EdgeMenus[${m}].modules`));
    const keys = ["location", "latitude", "longitude", "units", "intervalMinutes"];
    const withProps = found.filter(f => f.item.properties && typeof f.item.properties === "object" && keys.some(key => key in f.item.properties));
    if (withProps.length === 0)
      return config;
    const isSet = props => ["location", "latitude", "longitude"].some(key => String(props[key] ?? "").trim() !== "");
    const source = withProps.find(f => isSet(f.item.properties)) ?? withProps[0];
    const sourceProps = Object.assign({}, source.item.properties);
    const intervals = withProps.map(f => Number(f.item.properties.intervalMinutes)).filter(n => !isNaN(n));
    if (!config.Weather || typeof config.Weather !== "object") {
      const weather = {};
      ["location", "latitude", "longitude", "units"].forEach(key => {
        if (key in sourceProps)
          weather[key] = sourceProps[key];
      });
      if (intervals.length > 0)
        weather.intervalMinutes = Math.min(...intervals);
      config.Weather = weather;
      changes.push(`Weather: location and units from ${source.where}`);
    }
    withProps.forEach(f => {
      const props = f.item.properties;
      if (f !== source && isSet(props) && ["location", "latitude", "longitude"].some(key => props[key] !== sourceProps[key]))
        changes.push(`${f.where}: its own location dropped: weather follows the Weather settings`);
      keys.forEach(key => delete props[key]);
      if (Object.keys(props).length === 0)
        delete f.item.properties;
    });
    return config;
  }

  // v34 put the built-in lock screen on a grid of modules
  // (Lockscreen.layout): the old one's greeting, playing track (unless
  // showMedia was off) and password field become modules where they were
  function _v33ToV34(config, changes) {
    const lockscreen = config.Lockscreen;
    if (!lockscreen || typeof lockscreen !== "object" || !("showMedia" in lockscreen))
      return config;
    const media = lockscreen.showMedia !== false;
    delete lockscreen.showMedia;
    if (lockscreen.layout && typeof lockscreen.layout === "object")
      return config;
    const at = (x, y, w, h) => ({
          "x": x,
          "y": y,
          "w": w,
          "h": h
        });
    const modules = [
      {
        "type": "Greeting",
        "place": at(4, 2, 8, 2)
      }
    ];
    if (media)
      modules.push({
        "type": "NowPlaying",
        "place": at(5, 4, 6, 2)
      });
    modules.push({
      "type": "Password",
      "place": at(5, media ? 6 : 4, 6, 1)
    });
    lockscreen.layout = {
      "modules": modules
    };
    changes.push(`Lockscreen: showMedia became the lock screen's modules${media ? " (with NowPlaying)" : ""}`);
    return config;
  }

  // v35: an edge menu sits centred on its edge, `offset` grid units from
  // the middle, instead of from an `align` anchor. A menu from an end gets
  // the furthest offset, which keeps it flush with that end
  function _v34ToV35(config, changes) {
    (Array.isArray(config.EdgeMenus) ? config.EdgeMenus : []).forEach((menu, m) => {
      if (!menu || typeof menu !== "object" || !("align" in menu))
        return;
      if (menu.align === "start" || menu.align === "end") {
        menu.offset = menu.align === "start" ? -200 : 200;
        changes.push(`EdgeMenus[${m}]: align "${menu.align}" -> offset ${menu.offset} (flush with that end)`);
      }
      delete menu.align;
    });
    return config;
  }

  // v36 dropped the primary bar: a surface opening on "primaryBar" (the
  // first bar's monitor) opens on the primary monitor
  function _v35ToV36(config, changes) {
    const retarget = (section, where) => {
      if (section && typeof section === "object" && section.monitors === "primaryBar") {
        section.monitors = "primary";
        changes.push(`${where}.monitors: "primaryBar" -> "primary"`);
      }
    };
    ["Launcher", "PowerMenu", "Notifications", "Overlay"].forEach(name => retarget(config[name], name));
    (Array.isArray(config.OSD?.osds) ? config.OSD.osds : []).forEach((osd, i) => retarget(osd, `OSD.osds[${i}]`));
    return config;
  }

  // v37 renamed the ThemeEditor module ThemePicker (it picks a theme)
  function _v36ToV37(config, changes) {
    const rename = (list, where) => (Array.isArray(list) ? list : []).forEach((module, i) => {
        if (module?.type !== "ThemeEditor")
          return;
        module.type = "ThemePicker";
        changes.push(`${where}[${i}]: ThemeEditor -> ThemePicker`);
      });
    (Array.isArray(config.Overlay?.views) ? config.Overlay.views : []).forEach((view, v) => rename(view?.modules, `Overlay.views[${v}].modules`));
    (Array.isArray(config.EdgeMenus) ? config.EdgeMenus : []).forEach((menu, m) => rename(menu?.modules, `EdgeMenus[${m}].modules`));
    rename(config.Lockscreen?.layout?.modules, "Lockscreen.layout.modules");
    return config;
  }

  // v38 added toggle split and special workspace binds, on SUPER + X and
  // SUPER (+ SHIFT) + V (Hyprland's example config has them on SUPER + J
  // and SUPER (+ SHIFT) + S, which axiom's hjkl and WASD use)
  function _v37ToV38(config, changes) {
    return root._addBinds(config, changes, [
      {
        "key": "SUPER + X",
        "action": "toggleSplit"
      },
      {
        "key": "SUPER + V",
        "action": "toggleSpecial",
        "argument": "magic"
      },
      {
        "key": "SUPER + SHIFT + V",
        "action": "moveToSpecial",
        "argument": "magic"
      }
    ]);
  }

  // v39 made a bar's widget backgrounds one of several styles
  // (`widgetFill`): off became plain text, keeping its text color. With
  // backgrounds on that color was unused, while it now overrides every
  // style's, so it goes.
  function _v38ToV39(config, changes) {
    (Array.isArray(config.Bars) ? config.Bars : []).forEach((bar, i) => {
      if (!bar || typeof bar !== "object" || !("widgetBackgrounds" in bar))
        return;
      const plain = bar.widgetBackgrounds === false;
      delete bar.widgetBackgrounds;
      if (plain) {
        bar.widgetFill = "plain";
        changes.push(`Bars[${i}].widgetBackgrounds: false -> widgetFill: "plain"`);
      } else {
        delete bar.widgetTextColor;
        changes.push(`Bars[${i}].widgetBackgrounds removed`);
      }
    });
    return config;
  }

  // v40 moved a bar's look (widget style, accents, shadow) into the
  // BarStyle section, each group of it overridable per bar
  // (`override<Group>`), and renamed widgetFill and the underline's
  // indicator keys. The first bar's look becomes everyone's; a bar whose
  // look differs from it in a group keeps its own there.
  readonly property var _v40Renames: ({
      "widgetFill": "widgetStyle",
      "indicatorWidth": "lineWidth",
      "indicatorSide": "lineSide"
    })
  readonly property var _v40Groups: ({
      "overrideWidgetStyle": ["widgetStyle", "tintOpacity", "outlineWidth", "lineWidth", "lineSide", "widgetShape", "widgetGrouping", "groupColor", "widgetTextColor"],
      "overrideAccents": ["separatorStyle", "separatorColor", "separatorThickness", "accentLine", "accentLineColor", "accentLineFade", "accentLineWidth"],
      "overrideShadow": ["shadow", "shadowColor", "shadowSize"]
    })
  function _v39ToV40(config, changes) {
    const bars = (Array.isArray(config.Bars) ? config.Bars : []).filter(bar => bar && typeof bar === "object");
    bars.forEach((bar, i) => {
      Object.keys(root._v40Renames).forEach(from => {
        if (!(from in bar))
          return;
        bar[root._v40Renames[from]] = bar[from];
        delete bar[from];
        changes.push(`Bars[${i}].${from} -> ${root._v40Renames[from]}`);
      });
    });
    if (bars.length === 0 || (config.BarStyle && typeof config.BarStyle === "object"))
      return config;
    const style = {};
    Object.keys(root._v40Groups).forEach(flag => root._v40Groups[flag].forEach(key => {
        if (key in bars[0])
          style[key] = bars[0][key];
      }));
    config.BarStyle = style;
    changes.push("BarStyle taken from Bars[0]");
    bars.forEach((bar, i) => {
      Object.keys(root._v40Groups).forEach(flag => {
        const own = root._v40Groups[flag].some(key => (key in bar) !== (key in style) || bar[key] !== style[key]);
        if (!own)
          return;
        bar[flag] = true;
        changes.push(`Bars[${i}].${flag}: true`);
      });
    });
    return config;
  }

  // v41 picks bar widget colors automatically (an empty value): every
  // widget's colors became Auto, text colors and Workspaces' cells (but the
  // active one) aside
  readonly property var _v41AutoColors: ({
      "Window": ["backgroundColor"],
      "Media": ["playingColor", "pausedColor"],
      "Workspaces": ["activeColor", "backgroundColor"],
      "Time": ["backgroundColor"],
      "Tailscale": ["connectedColor", "disconnectedColor"],
      "Network": ["backgroundColor", "disconnectedColor"],
      "SystemTray": ["backgroundColor"],
      "Notifications": ["backgroundColor", "dndColor", "badgeColor"],
      "Button": ["backgroundColor"],
      "Battery": ["backgroundColor", "chargingColor", "lowColor", "criticalColor"],
      "SystemStats": ["backgroundColor", "warnColor"],
      "KeyboardLayout": ["backgroundColor"],
      "IdleInhibitor": ["activeColor", "inactiveColor"],
      "Privacy": ["activeColor"],
      "ScreenRecord": ["activeColor"],
      "Updates": ["backgroundColor", "manyColor"],
      "ClaudeUsage": ["backgroundColor", "warnColor", "criticalColor"],
      "Weather": ["backgroundColor"],
      "Volume": ["backgroundColor", "mutedColor"],
      "Microphone": ["activeColor", "backgroundColor", "mutedColor"],
      "Bluetooth": ["backgroundColor", "connectedColor", "disabledColor"]
    })
  function _v40ToV41(config, changes) {
    _eachWidget(config, (widget, where) => {
      const properties = widget.properties;
      if (!properties || typeof properties !== "object")
        return;
      (root._v41AutoColors[widget.type] ?? []).forEach(key => {
        if (!properties[key])
          return;
        properties[key] = "";
        changes.push(`${where}.properties.${key} -> Auto`);
      });
    });
    return config;
  }

  // v42 replaced edge menus' and docks' `edgeDistance` with `detached`
  // (above 0) and a `gap` from the frame line (the border's stroke, or the
  // bar there) on their edge and at their ends. A menu's box sat its
  // distance past the stroke's outer edge, plus half a connector gap (a
  // corner radius): that, less the stroke, is its gap. A dock's distance
  // was already its gap, but the old default (8) becomes Auto, since
  // defaults filled it into every saved dock.
  function _v41ToV42(config, changes) {
    const shape = config.Appearance?.shape ?? {};
    const radius = typeof shape.radius === "number" ? shape.radius : 6;
    const stroke = typeof shape.borderWidth === "number" ? shape.borderWidth : 1;
    const detach = (entry, where, gapOf) => {
      if (!entry || typeof entry !== "object" || !("edgeDistance" in entry))
        return;
      const distance = typeof entry.edgeDistance === "number" ? entry.edgeDistance : 0;
      delete entry.edgeDistance;
      entry.detached = distance > 0;
      entry.gap = distance > 0 ? gapOf(distance) : -1;
      changes.push(`${where}.edgeDistance ${distance} -> detached: ${entry.detached}, gap: ${entry.gap < 0 ? "Auto" : entry.gap}`);
    };
    if (Array.isArray(config.EdgeMenus))
      config.EdgeMenus.forEach((menu, i) => detach(menu, `EdgeMenus[${i}]`, distance => Math.max(0, distance + radius - stroke)));
    if (Array.isArray(config.Dock?.docks))
      config.Dock.docks.forEach((dock, i) => detach(dock, `Dock.docks[${i}]`, distance => distance === 8 ? -1 : distance));
    return config;
  }

  // v43 gave docks the OSDs' `monitors` (with a specific monitor as one
  // more choice): "*" (all monitors) becomes "all", a named monitor
  // "monitor" with the name kept, and empty (the primary monitor) "general"
  // where General's is the primary monitor too, else "primary"
  function _v42ToV43(config, changes) {
    const docks = config.Dock?.docks;
    if (!Array.isArray(docks))
      return config;
    const generalPrimary = (config.General?.monitors ?? "primary") === "primary";
    docks.forEach((dock, i) => {
      if (!dock || typeof dock !== "object" || "monitors" in dock)
        return;
      const monitor = typeof dock.monitor === "string" ? dock.monitor : "";
      if (monitor === "*") {
        dock.monitors = "all";
        dock.monitor = "";
      } else if (monitor !== "") {
        dock.monitors = "monitor";
      } else {
        dock.monitors = generalPrimary ? "general" : "primary";
      }
      changes.push(`Dock.docks[${i}].monitor "${monitor}" -> monitors: "${dock.monitors}"`);
    });
    return config;
  }

  // v44 dropped an OSD's `placement`: every OSD is on an edge, and one
  // that floated is held off the edge nearest it (`detached`, Auto gap),
  // at the same spot along it. Its `x` was % across from the left and `y`
  // % up from the bottom.
  function _v43ToV44(config, changes) {
    (Array.isArray(config.OSD?.osds) ? config.OSD.osds : []).forEach((osd, i) => {
      if (!osd || typeof osd !== "object" || !("placement" in osd || "x" in osd || "y" in osd))
        return;
      const floating = osd.placement === "floating";
      const x = typeof osd.x === "number" ? osd.x : 50;
      const y = typeof osd.y === "number" ? osd.y : 33;
      delete osd.placement;
      delete osd.x;
      delete osd.y;
      if (!floating)
        return;
      const edges = [
        {
          "edge": "Left",
          "distance": x,
          "position": 100 - y
        },
        {
          "edge": "Right",
          "distance": 100 - x,
          "position": 100 - y
        },
        {
          "edge": "Bottom",
          "distance": y,
          "position": x
        },
        {
          "edge": "Top",
          "distance": 100 - y,
          "position": x
        }
      ];
      const nearest = edges.reduce((best, e) => e.distance < best.distance ? e : best);
      osd.edge = nearest.edge;
      osd.position = nearest.position;
      osd.detached = true;
      osd.gap = -1;
      changes.push(`OSD.osds[${i}]: floating at ${x}%, ${y}% -> detached on the ${nearest.edge} edge at ${nearest.position}%`);
    });
    return config;
  }

  // v45 moved Hyprland's scrolling layout out of Hyprland.managed into
  // Workspaces.strips (per monitor, in every Hyprland mode): a managed
  // config on `scrolling` becomes a strip on every monitor, its direction
  // folded into horizontal or vertical, over dwindle. The column width and
  // follow-focus settings move with it. Only in managed mode, where the
  // layout was in effect: strips apply in every mode.
  function _v44ToV45(config, changes) {
    const managed = config.Hyprland?.managed;
    if (!managed || typeof managed !== "object")
      return config;
    const scrolling = managed.layout === "scrolling";
    if (scrolling)
      managed.layout = "dwindle";
    const direction = ["down", "up"].includes(managed.scrollDirection) ? "vertical" : "horizontal";
    const width = managed.columnWidth;
    const follow = managed.scrollFollowFocus;
    delete managed.columnWidth;
    delete managed.scrollDirection;
    delete managed.scrollFollowFocus;
    if (!scrolling || config.Hyprland.mode !== "managed")
      return config;
    const workspaces = config.Workspaces && typeof config.Workspaces === "object" ? config.Workspaces : {};
    workspaces.strips = [
      {
        "monitor": "*",
        "direction": direction
      }
    ];
    if (width !== undefined)
      workspaces.stripColumnWidth = width;
    if (follow !== undefined)
      workspaces.stripFollowFocus = follow;
    config.Workspaces = workspaces;
    changes.push(`Hyprland.managed.layout "scrolling" -> Workspaces.strips: every monitor, ${direction}`);
    return config;
  }

  // v46 added the Calendar page (Calendar section): a page list saved
  // without it gets it once, as in v18
  function _v45ToV46(config, changes) {
    const views = config.Overlay?.views;
    if (!Array.isArray(views) || views.some(view => view?.type === "CalendarPage"))
      return config;
    views.push({
      "type": "CalendarPage"
    });
    changes.push("Overlay.views: added the Calendar page");
    return config;
  }

  // v47 placed the launcher as docks and OSDs are: on a screen edge, at a
  // position along it, attached or detached (then a distance across the
  // free screen, 50% centring it), instead of four fixed places
  function _v46ToV47(config, changes) {
    const launcher = config.Launcher;
    if (!launcher || typeof launcher.position !== "string")
      return config;
    const old = launcher.position;
    const place = {
      "center": {
        "edge": "Top",
        "detached": true,
        "distance": 50
      },
      "upper": {
        "edge": "Top",
        "detached": true,
        "distance": 30
      },
      "top": {
        "edge": "Top",
        "detached": false
      },
      "bottom": {
        "edge": "Bottom",
        "detached": false
      }
    }[old] ?? {};
    delete launcher.position;
    Object.assign(launcher, place);
    changes.push(`Launcher.position "${old}" -> ${JSON.stringify(place)}`);
    return config;
  }

  // v48 laid floating bars out like windows, their float gap Automatic
  // (Hyprland's gaps_out) by default: a bar left at the old default, 8,
  // takes Automatic
  function _v47ToV48(config, changes) {
    (Array.isArray(config.Bars) ? config.Bars : []).forEach(bar => {
      if (bar?.floatGap !== 8)
        return;
      bar.floatGap = -1;
      changes.push(`Bars[${bar.id}].floatGap 8 -> -1 (Automatic)`);
    });
    return config;
  }
}
