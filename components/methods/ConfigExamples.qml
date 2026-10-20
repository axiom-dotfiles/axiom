pragma Singleton
import QtQuick

// Sharing a config. Each setting's `x-scope` in the schema says whether it
// belongs to the look of a desktop or to the PC and person it runs for
// (inherited from the nearest ancestor that sets one; the root is machine):
//   look      how the desktop looks and is laid out
//   personal  preferences, keybinds and apps: travel only when asked for
//   commands  anything that runs as you (a command, a terminal, an exec
//             bind): travel only when asked for, on their own
//   machine   what only means something here: monitors, wallpapers,
//             accounts, paths, hardware and services
// An array item can have a scope of its own by what it holds
// (`x-scopeIf: { when, scope }`, `when` as x-showIf over the item's keys):
// an exec bind is commands, an app's OSD bar personal. Such an item is
// left out where its scope isn't carried, and applying keeps the user's.
// Example setups (examples/*.json) and exported configs hold the look (and,
// when asked, the personal parts and the commands: `carry`, a list of
// "personal" and "commands"); saved snapshots hold all three, plus the
// wallpaper setup (`x-snapshot`). Applying one replaces those parts of the
// running config and leaves the rest as the user set it.
QtObject {
  id: root

  // What a snapshot carries besides the look
  readonly property var everything: ["personal", "commands"]

  // The parts of `config` a shared file holds: the look, and the scopes in
  // `carry` ("personal", "commands"), never a takeover setting. With
  // `monitors` (monitorOrder's), each monitor a per-monitor part names
  // (`x-monitorRef`) is written by its place: "#1" the leftmost, "#2" the
  // next, "@primary" the primary monitor, "*" all of them
  function pick(config, schema, carry = [], monitors = null) {
    return _pick(config, schema, "machine", _context(carry, monitors), schema) ?? {};
  }

  // A copy of `current` with the example's parts in place of its own. Both
  // are whole configs of the same version (load the example first, so it is
  // migrated and filled). A part replaces the current one outright, so
  // nothing of the old layout (a bar, a menu) is left behind; inside it,
  // what isn't taken (a bar's monitor, a dock's pinned apps) stays the
  // user's, from the same item: by id or name, or else (machine values
  // only) by position. With no such item it is the default. A monitor
  // written by its place (pick) is the user's monitor in that place
  // (`monitors`: monitorOrder's); a part for one the user doesn't have is
  // turned off (`x-monitorRef: "off"`: a bar, dock, OSD, edge menu) or left
  // out ("drop": a strip, a monitor's own desktop), so nothing piles up on
  // the primary monitor.
  function apply(current, example, schema, carry = [], monitors = null) {
    return _merge(current, example, schema, "machine", _context(carry, monitors), true, schema);
  }

  // The monitors' names by place, left to right (then top to bottom), from
  // outputs ([{ name, x, y }])
  function monitorOrder(outputs) {
    return Array.from(outputs ?? []).slice().sort((a, b) => a.x - b.x || a.y - b.y).map(output => output.name);
  }

  // Settings that became part of a shared file at a version (moved into
  // a carried scope, or into WindowLook from Hyprland.managed, where a file
  // never held them): applying a file older than that keeps the user's
  // value of each it doesn't hold, instead of its default
  readonly property var movedKeys: [
    {
      "version": 58,
      "paths": ["WindowLook.shape", "WindowLook.matchShell", "WindowLook.borderSize", "WindowLook.rounding"]
    },
    {
      "version": 63,
      "paths": ["WindowLook.shadow", "WindowLook.shadowMatchShell", "WindowLook.shadowSize", "WindowLook.shadowPower", "WindowLook.shadowColor", "WindowLook.dim", "WindowLook.dimStrength"]
    },
    {
      "version": 71,
      "paths": ["Greeter.layout", "Desktop.monitors", "Idle.dimTimeout", "Idle.dimMode", "Idle.dimLevel", "Idle.dimBy", "Idle.lockTimeout", "Idle.screenOffTimeout", "Idle.suspendTimeout", "Idle.lockBeforeSleep", "Idle.screenOnAfterSleep", "Idle.respectInhibitors", "Idle.listeners", "NightLight.schedule", "NightLight.startAt", "NightLight.endAt", "NightLight.temperature", "NightLight.gamma", "General.language", "Launcher.monitors", "Launcher.edge", "Launcher.position", "Launcher.detached", "Launcher.distance", "Launcher.reverse", "Launcher.width", "Launcher.maxResults", "Launcher.iconSize", "Launcher.showBackdrop", "Launcher.backdrop", "Launcher.showDescriptions", "Launcher.showRecent", "Launcher.showHint", "Launcher.hiddenApps", "Launcher.windows", "Launcher.calculator", "Launcher.commands", "Launcher.runCommands", "Launcher.webSearch", "Launcher.searchEngine", "Launcher.chat", "Launcher.clipboard", "Launcher.clipboardMaxEntries", "Launcher.emoji", "PowerMenu.monitors", "Notifications.monitors", "Notifications.timeout", "Notifications.appTimeouts", "Notifications.criticalStays", "Notifications.quietFullscreen", "Notifications.clearOnFocus", "Notifications.removeOnClick", "Notifications.closeRemoves", "Notifications.maxEntries", "Notifications.maxAgeDays", "Hyprland.managed.layout", "Hyprland.managed.preserveSplit", "Hyprland.managed.smartSplit", "Hyprland.managed.smartResizing", "Hyprland.managed.forceSplit", "Hyprland.managed.splitRatio", "Hyprland.managed.masterSize", "Hyprland.managed.masterOrientation", "Hyprland.managed.masterNewStatus", "Hyprland.managed.snap", "Hyprland.managed.dimSpecial", "Hyprland.managed.animations", "Hyprland.managed.animationPreset", "Hyprland.managed.workspaceWraparound", "Hyprland.managed.curves", "Hyprland.managed.customAnimations", "Hyprland.managed.floatSwitchOverrideFocus", "Hyprland.managed.resizeOnBorder", "Hyprland.managed.hideLogo", "Hyprland.managed.backgroundThemed", "Hyprland.managed.backgroundColor", "Hyprland.managed.swallow", "Hyprland.managed.swallowRegex", "Hyprland.managed.closeSpecialOnEmpty", "Hyprland.managed.hideSpecialOnWorkspaceChange", "WindowBehaviour.followMouse", "WindowBehaviour.focusOnActivate", "WindowBehaviour.workspaceBackAndForth", "WindowBehaviour.cursorHideTimeout", "WindowBehaviour.hideCursorOnKeyPress", "WindowBehaviour.noWarps", "Sway.workspaceLayout", "Sway.hideEdgeBorders", "Sway.smartGaps", "Sway.focusWrapping", "Sway.popupDuringFullscreen", "Sway.font", "Niri.centerFocusedColumn", "Niri.alwaysCenterSingleColumn", "Niri.emptyWorkspaceAboveFirst", "Niri.defaultColumnDisplay", "Niri.hotCorner", "Niri.overviewZoom", "Niri.animations", "Niri.animationSlowdown", "Niri.preferNoCsd", "Niri.skipHotkeyOverlay", "Niri.primaryClipboard", "Input.kbLayout", "Input.kbVariant", "Input.kbOptions", "Input.repeatRate", "Input.repeatDelay", "Input.numlockByDefault", "Input.leftHanded", "Input.naturalScroll", "Input.tapToClick", "Input.disableWhileTyping", "Input.cursorTheme", "Input.cursorSize", "Appearance.themeSchedule", "Chat.defaultPreset", "Chat.keepConversations", "Chat.showThinking", "Chat.renderMarkdown", "Chat.sendKey", "Chat.presets", "Notes.extensions", "Notes.showHidden", "Notes.confirmDelete", "Calendar.defaultDuration", "Calendar.defaultReminder", "Calendar.reminders", "Calendar.pastMonths", "Calendar.futureMonths", "Calendar.use24Hour", "Calendar.maxDots", "Weather.units", "Overlay.monitors", "Overlay.closeOnEscape", "Overlay.closeOnOutsideClick", "WindowSwitcher.scope", "WindowSwitcher.showDelay"]
    }
  ]

  // A copy of `config` (a file of `version`, loaded) with each of
  // movedKeys newer than the file as it is in `current`, unless the file
  // holds it: `held` is the file migrated but not filled (an older whole
  // config.json holds them; an export or example didn't)
  function keepMovedKeys(config, held, current, version) {
    const result = Utils.clone(config);
    for (const moved of root.movedKeys) {
      if (version >= moved.version)
        continue;
      for (const dotted of moved.paths) {
        const path = dotted.split(".");
        const value = _at(current, path);
        if (value !== undefined && _at(held, path) === undefined && _isObject(_at(result, path.slice(0, -1))))
          _setAt(result, path, Utils.clone(value));
      }
    }
    return result;
  }

  // `config` without what loading fills back in: each key whose value is
  // the one it would get if it were missing
  function sparse(config, schema) {
    return _sparse(config, schema, schema);
  }

  // A copy of `config` with every `x-takeover` setting (one that takes
  // something over on this PC: the compositor mode, the lock screen, idle,
  // polkit, the greeter) as it is in `current`. Loading a saved config or
  // the defaults never changes them: each is switched by its own card,
  // which does the takeover or gives it back. `paths`: takeoverPaths(schema)
  // (ConfigManager.takeoverPaths).
  function keepTakeovers(config, current, paths) {
    const result = Utils.clone(config);
    for (const path of paths) {
      let from = current;
      let to = result;
      for (let i = 0; i < path.length - 1 && _isObject(from) && _isObject(to); i++) {
        from = from[path[i]];
        to = to[path[i]];
      }
      const key = path[path.length - 1];
      if (_isObject(from) && _isObject(to) && from[key] !== undefined)
        to[key] = Utils.clone(from[key]);
    }
    return result;
  }

  // What a saved snapshot holds: the look, the personal parts and the
  // commands, and the `x-snapshot` settings (the wallpaper setup). Those
  // are machine values, but a snapshot restores on the PC it was saved on,
  // where they still mean something (withSnapshot).
  function snapshot(config, schema) {
    const result = pick(config, schema, root.everything);
    for (const path of snapshotPaths(schema)) {
      const value = _at(config, path);
      if (value !== undefined)
        _setAt(result, path, Utils.clone(value));
    }
    return result;
  }

  // The files (absolute paths, each once) the `x-snapshot` settings of
  // `config` name as file:// URLs, to check which are still there before
  // restoring them
  function snapshotFiles(config, schema) {
    const urls = [];
    const collect = value => {
      if (typeof value === "string" && value.startsWith("file://"))
        urls.push(value);
      else if (_isObject(value))
        Object.values(value).forEach(collect);
    };
    for (const path of snapshotPaths(schema))
      collect(_at(config, path));
    return urls.map(_filePath).filter((path, i, all) => path.startsWith("/") && all.indexOf(path) === i);
  }

  // A copy of `config` with the `x-snapshot` settings of `saved`. A file
  // URL comes back only when its file is in `existing` (snapshotFiles'
  // paths that exist), and a wallpaper is never blanked: otherwise the one
  // in `config` stays. Objects merge by key (a monitor not in the
  // snapshot keeps its wallpaper).
  function withSnapshot(config, saved, schema, existing) {
    const result = Utils.clone(config);
    const restore = (current, value) => {
      if (typeof value === "string") {
        if (value.startsWith("file://"))
          return existing.includes(_filePath(value)) ? value : current;
        return value === "" && typeof current === "string" && current.startsWith("file://") ? current : value;
      }
      if (!_isObject(value))
        return Utils.clone(value);
      const merged = _isObject(current) ? Utils.clone(current) : {};
      for (const key in value) {
        const restored = restore(merged[key], value[key]);
        if (restored !== undefined)
          merged[key] = restored;
      }
      return merged;
    };
    for (const path of snapshotPaths(schema)) {
      const value = _at(saved, path);
      if (value !== undefined)
        _setAt(result, path, restore(_at(result, path), value));
    }
    return result;
  }

  // The paths ([key, …]) of the `x-takeover` settings, through objects only
  function takeoverPaths(schema) {
    return _annotated(schema, "x-takeover");
  }

  // The paths of the `x-snapshot` settings, through objects only
  function snapshotPaths(schema) {
    return _annotated(schema, "x-snapshot");
  }

  function _annotated(schema, annotation) {
    const paths = [];
    const walk = (node, path, depth) => {
      node = SchemaValidation.resolveRef(node, schema);
      if (!node || depth > 20)
        return;
      if (node[annotation] === true && path.length > 0) {
        paths.push(path);
        return;
      }
      for (const key in node.properties ?? {})
        walk(node.properties[key], path.concat([key]), depth + 1);
    };
    walk(schema, [], 0);
    return paths;
  }

  function _at(value, path) {
    for (const key of path) {
      if (!_isObject(value))
        return undefined;
      value = value[key];
    }
    return value;
  }

  // Sets the value at `path`, making the objects on the way
  function _setAt(target, path, value) {
    for (const key of path.slice(0, -1)) {
      if (!_isObject(target[key]))
        target[key] = {};
      target = target[key];
    }
    target[path[path.length - 1]] = value;
  }

  function _filePath(url) {
    try {
      return decodeURIComponent(url.replace(/^file:\/\//, ""));
    } catch (e) {
      return "";
    }
  }

  // What a walk carries: { kept: scopes, monitors: names by place or null }
  function _context(carry, monitors) {
    return {
      kept: ["look"].concat(carry ?? []),
      monitors: monitors
    };
  }

  // A monitor name as its place (pick), or undefined for one not connected
  function _monitorToken(name, monitors) {
    if (name === "")
      return "@primary";
    if (name === "*")
      return name;
    const index = monitors.indexOf(name);
    return index < 0 ? undefined : "#" + (index + 1);
  }

  function _isMonitorToken(value) {
    return typeof value === "string" && (value === "@primary" || value === "*" || /^#[1-9][0-9]*$/.test(value));
  }

  // The user's monitor for a place, "" (the primary) for one they don't have
  function _monitorName(token, monitors) {
    if (token === "@primary")
      return "";
    if (token === "*")
      return token;
    return (monitors ?? [])[parseInt(token.slice(1)) - 1] ?? "";
  }

  // What becomes of `item` when it names a place the user has no monitor
  // for: its field's `x-monitorRef` ("off" or "drop"), else ""
  function _monitorMissing(item, items, ctx, rootSchema) {
    const node = _node(item, items, "", rootSchema).schema;
    if (!_isObject(item) || !node?.properties)
      return "";
    for (const key of Object.keys(node.properties)) {
      const rule = SchemaValidation.resolveRef(node.properties[key], rootSchema)?.["x-monitorRef"];
      const value = item[key];
      if (rule && /^#[1-9][0-9]*$/.test(value ?? "") && parseInt(value.slice(1)) > (ctx.monitors ?? []).length)
        return rule;
    }
    return "";
  }

  // { schema, scope, own } for `value` at `schema`: the $ref resolved, the
  // oneOf option for its type (schema null when none matches), the scope
  // it has; `own` when that's the item's own (x-scopeIf)
  function _node(value, schema, scope, rootSchema) {
    let node = SchemaValidation.resolveRef(schema, rootSchema);
    scope = node?.["x-scope"] ?? scope;
    if (node?.oneOf)
      node = SchemaValidation.oneOfOption(value, node, rootSchema);
    const own = _ownScope(value, node);
    return {
      schema: node ?? null,
      scope: own ?? node?.["x-scope"] ?? scope,
      own: own !== null
    };
  }

  // The scope an item has by what it holds (x-scopeIf), or null
  function _ownScope(value, node) {
    const rule = node?.["x-scopeIf"];
    if (!rule || !_isObject(value))
      return null;
    return SchemaLayout.showIfHolds(rule.when, key => value[key]) ? rule.scope : null;
  }

  // Whether an item of `items` (an array's item schema) has a scope of its
  // own that isn't kept: left out of a pick, and the user's kept on apply
  function _ownNotKept(item, items, scope, ctx, rootSchema) {
    const node = _node(item, items, scope, rootSchema);
    return node.own && !ctx.kept.includes(node.scope);
  }

  function _child(schema, key) {
    if (schema?.properties?.[key])
      return schema.properties[key];
    return typeof schema?.additionalProperties === "object" ? schema.additionalProperties : null;
  }

  function _isObject(value) {
    return typeof value === "object" && value !== null && !Array.isArray(value);
  }

  // Whether anything at or under `schema` has a kept scope
  function _carries(schema, scope, ctx, rootSchema, depth = 0) {
    const node = SchemaValidation.resolveRef(schema, rootSchema);
    if (!node || depth > 40)
      return false;
    scope = node["x-scope"] ?? scope;
    if (ctx.kept.includes(scope))
      return true;
    const children = [].concat(node.oneOf ?? [], Object.values(node.properties ?? {}), node.items ? [node.items] : [], typeof node.additionalProperties === "object" ? [node.additionalProperties] : []);
    return children.some(child => _carries(child, scope, ctx, rootSchema, depth + 1));
  }

  // `value` with only its kept parts, or undefined for none (a takeover
  // setting is never kept: loading one keeps the running value)
  function _pick(value, schema, scope, ctx, rootSchema) {
    const node = _node(value, schema, scope, rootSchema);
    if (node.schema?.["x-takeover"] === true)
      return undefined;
    if (node.schema?.["x-monitorRef"] && ctx.monitors && typeof value === "string")
      return _monitorToken(value, ctx.monitors);
    const keep = ctx.kept.includes(node.scope);
    if (Array.isArray(value)) {
      if (!keep)
        return undefined;
      const items = node.schema?.items;
      if (!items)
        return Utils.clone(value);
      return value.filter(item => !_ownNotKept(item, items, node.scope, ctx, rootSchema)).map(item => _pick(item, items, node.scope, ctx, rootSchema)).filter(item => item !== undefined);
    }
    if (_isObject(value) && node.schema) {
      const result = {};
      for (const key in value) {
        const child = _child(node.schema, key);
        const picked = child ? _pick(value[key], child, node.scope, ctx, rootSchema) : keep ? Utils.clone(value[key]) : undefined;
        if (picked !== undefined)
          result[key] = picked;
      }
      return keep || Object.keys(result).length > 0 ? result : undefined;
    }
    return keep ? Utils.clone(value) : undefined;
  }

  // The applied value at one place. `strict`: `current` is the example's
  // item by id or name all the way up, not just by position, so a personal
  // value not taken carries over from it.
  function _merge(current, example, schema, scope, ctx, strict, rootSchema) {
    const node = _node(example !== undefined ? example : current, schema, scope, rootSchema);
    if (node.schema?.["x-monitorRef"] && _isMonitorToken(example))
      return _monitorName(example, ctx.monitors);
    if (!ctx.kept.includes(node.scope))
      return _keep(current, example, node, ctx, strict, rootSchema);
    if (example === undefined)
      return Utils.clone(current);
    if (Array.isArray(example)) {
      const items = node.schema?.items;
      if (!items)
        return Utils.clone(example);
      const taken = example.filter(item => !_ownNotKept(item, items, node.scope, ctx, rootSchema));
      // The user's own items of a scope not taken stay, after the example's
      const own = Array.isArray(current) ? current.filter(item => _ownNotKept(item, items, node.scope, ctx, rootSchema)) : [];
      return taken.map((item, i) => {
        const match = _match(current, item, i, taken);
        const merged = _merge(match.item, item, items, node.scope, ctx, strict && match.strict, rootSchema);
        const missing = _monitorMissing(item, items, ctx, rootSchema);
        if (missing === "drop")
          return undefined;
        if (missing === "off")
          merged.enabled = false;
        return merged;
      }).filter(item => item !== undefined).concat(Utils.clone(own));
    }
    if (_isObject(example) && node.schema) {
      // An item of another type has none of this one's values
      if (_isObject(current) && current.type !== example.type)
        current = undefined;
      const result = {};
      for (const key in example) {
        const child = _child(node.schema, key);
        const merged = child ? _merge(current?.[key], example[key], child, node.scope, ctx, strict, rootSchema) : Utils.clone(example[key]);
        if (merged !== undefined)
          result[key] = merged;
      }
      return result;
    }
    return Utils.clone(example);
  }

  // A part not taken from the example: the user's (a personal one only from
  // a strict match), or else its default. Its kept parts are still taken.
  function _keep(current, example, node, ctx, strict, rootSchema) {
    const usable = current !== undefined && (node.scope === "machine" || strict);
    if (_isObject(current) && _isObject(example) && node.schema && _carries(node.schema, node.scope, ctx, rootSchema)) {
      const result = {};
      const keys = Object.keys(Object.assign({}, current, example));
      for (const key of keys) {
        const child = _child(node.schema, key);
        const merged = child ? _merge(usable ? current[key] : undefined, example[key], child, node.scope, ctx, strict, rootSchema) : Utils.clone(usable ? current[key] : example[key]);
        if (merged !== undefined)
          result[key] = merged;
      }
      return result;
    }
    if (usable)
      return Utils.clone(current);
    return node.schema ? SchemaValidation.applyDefaults(undefined, node.schema, rootSchema) : undefined;
  }

  // The item of `list` that `item` (at `index` in its own list `own`) stands
  // for: { item, strict }, strict when found by id or name, or for a typed
  // item with neither (a bar widget, a module) as the same nth of its type
  function _match(list, item, index, own) {
    if (!Array.isArray(list))
      return {
        item: undefined,
        strict: false
      };
    for (const key of ["id", "name"]) {
      const value = item?.[key];
      if (typeof value !== "string" || value === "")
        continue;
      const found = list.find(other => other?.[key] === value);
      if (found !== undefined)
        return {
          item: found,
          strict: true
        };
    }
    const type = item?.type;
    if (typeof type === "string" && type !== "" && Array.isArray(own)) {
      const nth = own.slice(0, index).filter(other => other?.type === type).length;
      const found = list.filter(other => other?.type === type)[nth];
      return {
        item: found,
        strict: found !== undefined
      };
    }
    return {
      item: list[index],
      strict: false
    };
  }

  function _sparse(value, schema, rootSchema) {
    const node = _node(value, schema, "", rootSchema).schema;
    if (Array.isArray(value))
      return value.map(item => node?.items ? _sparse(item, node.items, rootSchema) : Utils.clone(item));
    if (!_isObject(value) || !node)
      return Utils.clone(value);
    const result = {};
    for (const key in value) {
      const child = _child(node, key);
      // `type` picks a oneOf's option, which is how the rest fills in
      if (child && key !== "type" && Utils.deepEqual(value[key], SchemaValidation.applyDefaults(undefined, child, rootSchema)))
        continue;
      result[key] = child ? _sparse(value[key], child, rootSchema) : Utils.clone(value[key]);
    }
    return result;
  }
}
