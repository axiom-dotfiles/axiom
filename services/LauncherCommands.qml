import QtQuick
import Quickshell

import qs.config

/*
 * The launcher's slash commands, one per shell feature. LauncherManager
 * filters and runs them; each entry is
 *   { name, aliases, glyph, description, usage,
 *     needsArg,   Enter without an argument completes "/name " instead
 *     confirm,    asks for a second Enter first (destructive session actions)
 *     available() whether it's listed at all
 *     status()    current state, shown on the command's row
 *     options(arg) completion rows [{ title, subtitle, glyph, image, value }]
 *     run(arg, value) value is the picked option's, else undefined;
 *                     returns false to keep the launcher open (where the
 *                     change shows, so several can be tried), or a string
 *                     to search for instead }
 * Descriptions are read when listed, so they follow the language.
 */
QtObject {
  id: root

  readonly property var list: [
    // --- Session ---
    root._session("lock", ["lock-screen"], "Lock the screen"), root._session("suspend", ["sleep"], "Suspend to RAM"), root._session("hibernate", [], "Hibernate to disk"), root._session("logout", ["exit"], "End the Hyprland session"), root._session("reboot", ["restart"], "Restart the computer"), root._session("poweroff", ["shutdown"], "Turn the computer off"),
    // --- Surfaces ---
    {
      name: "power",
      aliases: ["powermenu"],
      glyph: "power_settings_new",
      description: () => I18n.tr("Open the power menu"),
      run: () => ShellManager.openPowerMenu()
    },
    {
      name: "workspaces",
      aliases: ["overview"],
      glyph: "grid_view",
      description: () => I18n.tr("Open the workspace overview"),
      run: () => ShellManager.toggleWorkspaceOverlay()
    },
    {
      name: "overlay",
      aliases: ["page"],
      glyph: "dashboard",
      usage: "[page]",
      description: () => I18n.tr("Open the overlay, or one of its pages"),
      options: () => root._overlayPages(),
      run: (arg, value) => {
        const page = value ?? arg.trim();
        if (page === "")
          ShellManager.toggleOverlay();
        else
          ShellManager.openOverlayPage(page);
      }
    },
    root._page("settings", ["prefs", "options"], "Settings", "Open the settings"), root._page("themes", [], "Themes", "Open the themes page"), root._page("bar", ["bareditor"], "BarEditor", "Open the bar editor"), root._page("keybinds", ["keys", "shortcuts"], "Keybinds", "Show the keybinds"), root._page("editor", ["overlay-editor"], "OverlayEditor", "Open the overlay editor"), root._page("menus", ["edge-menus", "menu-editor"], "EdgeMenuEditor", "Open the edge menu editor"),
    // --- Appearance ---
    {
      name: "theme",
      aliases: ["colors"],
      glyph: "palette",
      usage: "<theme>",
      needsArg: true,
      description: () => I18n.tr("Switch the color theme"),
      status: () => ThemeManager.currentFamily?.label ?? Appearance.theme,
      options: () => ThemeManager.themeFamilies.map(family => ({
              title: family.label,
              subtitle: family === ThemeManager.currentFamily ? I18n.tr("Current") : family.generated ? I18n.tr("Generated") : family.dark && family.light ? I18n.tr("Dark and light") : family.dark ? I18n.tr("Dark") : I18n.tr("Light"),
              value: family
            })),
      run: (arg, value) => {
        if (value)
          ThemeManager.applyFamily(value);
        return false;
      }
    },
    {
      name: "dark",
      aliases: [],
      glyph: "clear_night",
      description: () => I18n.tr("Use the theme's dark variant"),
      run: () => {
        ThemeManager.setLightMode(false);
        return false;
      }
    },
    {
      name: "light",
      aliases: [],
      glyph: "sunny",
      description: () => I18n.tr("Use the theme's light variant"),
      run: () => {
        ThemeManager.setLightMode(true);
        return false;
      }
    },
    {
      name: "mode",
      aliases: ["darkmode"],
      glyph: "contrast",
      description: () => I18n.tr("Toggle light and dark"),
      status: () => Appearance.darkMode ? I18n.tr("Dark") : I18n.tr("Light"),
      run: () => {
        ThemeManager.toggleDarkMode();
        return false;
      }
    },
    {
      name: "wallpaper",
      aliases: ["wall", "bg"],
      glyph: "image",
      usage: "<file>",
      needsArg: true,
      description: () => I18n.tr("Set the focused monitor's wallpaper"),
      options: () => root._wallpapers(),
      run: (arg, value) => {
        let url = value;
        if (url === "random") {
          const walls = root._wallpapers().slice(1);
          url = walls.length > 0 ? walls[Math.floor(Math.random() * walls.length)].value : "";
        }
        if (url)
          ThemeManager.setWallpaperAndGenerate(url, "");
        return false;
      }
    },
    {
      name: "generate",
      aliases: ["pywal"],
      glyph: "auto_fix",
      description: () => I18n.tr("Generate themes from the current wallpaper"),
      status: () => ThemeManager.isGenerating ? I18n.tr("Generating…") : "",
      run: () => {
        const monitor = ShellManager.targetFor(LauncherConfig.monitors);
        const wallpaper = Appearance.wallpapers[monitor] || Appearance.wallpaper;
        if (wallpaper)
          ThemeManager.generateThemesFromWallpaper(wallpaper);
      }
    },
    // --- Audio & media ---
    {
      name: "volume",
      aliases: ["vol"],
      glyph: "volume_up",
      usage: "<0-100 | +n | -n>",
      needsArg: true,
      description: () => I18n.tr("Set the output volume"),
      status: () => AudioManager.muted ? I18n.tr("Muted") : Math.round(AudioManager.volume * 100) + "%",
      run: arg => {
        const match = arg.trim().match(/^([+-]?)(\d+)%?$/);
        if (match) {
          const amount = parseInt(match[2]) / 100;
          if (match[1] === "+")
            AudioManager.increaseVolume(amount);
          else if (match[1] === "-")
            AudioManager.decreaseVolume(amount);
          else
            AudioManager.setVolume(amount);
        }
        return false;
      }
    },
    {
      name: "mute",
      aliases: [],
      glyph: "volume_off",
      description: () => I18n.tr("Mute or unmute the output"),
      status: () => AudioManager.muted ? I18n.tr("Muted") : "",
      run: () => {
        AudioManager.toggleMute();
        return false;
      }
    },
    {
      name: "mic",
      aliases: ["microphone"],
      glyph: "mic",
      description: () => I18n.tr("Mute or unmute the microphone"),
      status: () => AudioManager.sourceMuted ? I18n.tr("Muted") : "",
      run: () => {
        AudioManager.toggleSourceMute();
        return false;
      }
    },
    root._device("output", ["sink", "speakers"], "speaker", "Choose the audio output", () => AudioManager.sinks, () => AudioManager.defaultSink), root._device("input", ["source"], "mic", "Choose the audio input", () => AudioManager.sources, () => AudioManager.defaultSource), root._media("play", ["pause"], "play_pause", "Play or pause", () => MediaManager.togglePlayPause()), root._media("next", ["skip"], "skip_next", "Next track", () => MediaManager.next()), root._media("prev", ["previous", "back"], "skip_previous", "Previous track", () => MediaManager.previous()),
    // --- Connectivity ---
    {
      name: "wifi",
      aliases: ["wlan"],
      glyph: "wifi",
      usage: "[on | off]",
      description: () => I18n.tr("Turn wifi on or off"),
      available: () => NetworkingManager.available,
      status: () => NetworkingManager.wifiEnabled ? I18n.tr("On") : I18n.tr("Off"),
      options: () => root._onOffOptions(),
      run: (arg, value) => {
        const on = root._onOff(value ?? arg);
        NetworkingManager.setWifiEnabled(on === null ? !NetworkingManager.wifiEnabled : on);
        return false;
      }
    },
    {
      name: "bluetooth",
      aliases: ["bt"],
      glyph: "bluetooth",
      usage: "[on | off]",
      description: () => I18n.tr("Turn bluetooth on or off"),
      available: () => BluetoothManager.available,
      status: () => BluetoothManager.enabled ? I18n.tr("On") : I18n.tr("Off"),
      options: () => root._onOffOptions(),
      run: (arg, value) => {
        const on = root._onOff(value ?? arg);
        BluetoothManager.setEnabled(on === null ? !BluetoothManager.enabled : on);
        return false;
      }
    },
    {
      name: "connect",
      aliases: ["disconnect", "device"],
      glyph: "bluetooth_connected",
      usage: "<device>",
      needsArg: true,
      description: () => I18n.tr("Connect or disconnect a paired bluetooth device"),
      available: () => BluetoothManager.enabled,
      options: () => BluetoothManager.pairedDevices.map(device => ({
              title: BluetoothManager.deviceLabel(device),
              subtitle: BluetoothManager.deviceStatus(device),
              glyph: BluetoothManager.deviceIcon(device),
              value: device
            })),
      run: (arg, value) => {
        if (value)
          BluetoothManager.toggleDevice(value);
      }
    },
    // --- Notifications & idle ---
    {
      name: "dnd",
      aliases: ["quiet"],
      glyph: "notifications_off",
      usage: "[on | off]",
      description: () => I18n.tr("Do not disturb"),
      status: () => NotificationManager.dnd ? I18n.tr("On") : I18n.tr("Off"),
      options: () => root._onOffOptions(),
      run: (arg, value) => {
        const on = root._onOff(value ?? arg);
        NotificationManager.dnd = on === null ? !NotificationManager.dnd : on;
        return false;
      }
    },
    {
      name: "clear",
      aliases: ["clear-notifications"],
      glyph: "clear_all",
      description: () => I18n.tr("Clear all notifications"),
      status: () => NotificationManager.count > 0 ? I18n.tr("{0} notifications", NotificationManager.count) : "",
      run: () => {
        NotificationManager.clearAll();
        return false;
      }
    },
    {
      name: "caffeine",
      aliases: ["awake", "inhibit"],
      glyph: "coffee",
      usage: "[on | off]",
      description: () => I18n.tr("Keep the screen awake"),
      status: () => IdleInhibitManager.enabled ? I18n.tr("On") : I18n.tr("Off"),
      options: () => root._onOffOptions(),
      run: (arg, value) => {
        const on = root._onOff(value ?? arg);
        IdleInhibitManager.enabled = on === null ? !IdleInhibitManager.enabled : on;
        return false;
      }
    },
    // --- Workspaces & shell ---
    {
      name: "ws",
      aliases: ["workspace"],
      glyph: "numbers",
      usage: "<number>",
      needsArg: true,
      description: () => I18n.tr("Go to a workspace"),
      run: arg => {
        const id = parseInt(arg.trim());
        if (id > 0)
          HyprlandManager.goToWorkspace(id);
        else
          return false;
      }
    },
    {
      name: "config",
      aliases: ["set", "cfg"],
      glyph: "settings",
      usage: "<setting> <value> | save <name> | restore <name>",
      needsArg: true,
      description: () => I18n.tr("Change a setting, or save and restore the config"),
      options: arg => root._configOptions(arg),
      run: (arg, value) => root._configRun(value)
    },
    {
      name: "chat",
      aliases: ["ai"],
      glyph: "smart_toy",
      usage: "[conversation]",
      description: () => I18n.tr("Open the chat, a new conversation or a saved one (@ asks a question)"),
      status: () => ChatManager.busy ? I18n.tr("Replying…") : ChatManager.conversation.title,
      options: () => [
          {
            title: I18n.tr("New conversation"),
            subtitle: ChatConfig.defaultPreset,
            glyph: "edit_square",
            value: ""
          }
        ].concat(ChatManager.conversations.map(c => ({
              title: c.title || I18n.tr("Untitled"),
              subtitle: I18n.formatDate(new Date(c.updated), I18n.dateFormat("mediumDate")),
              glyph: "chat",
              value: c.id
            }))),
      run: (arg, value) => {
        // After the launcher has closed, so the overlay gets the keyboard
        Qt.callLater(() => {
          if (value === "")
            ChatManager.newConversation(ChatConfig.defaultPreset);
          else if (value !== undefined)
            ChatManager.open(value);
          ChatManager.openPage();
        });
      }
    },
    {
      name: "update",
      aliases: ["upgrade"],
      glyph: "update",
      description: () => SelfUpdateManager.available ? I18n.tr("Update axiom to {0}", SelfUpdateManager.latest) : I18n.tr("Check for axiom updates"),
      status: () => SelfUpdateManager.busy ? I18n.tr("Checking…") : SelfUpdateManager.available ? I18n.tr("{0} available", SelfUpdateManager.latest) : (SelfUpdateManager.current || SelfUpdateManager.commit),
      run: () => {
        // Otherwise check, on the page that shows the result
        if (SelfUpdateManager.available) {
          SelfUpdateManager.apply();
        } else {
          SelfUpdateManager.check();
          SelfUpdateManager.openSettings();
        }
      }
    },
    {
      name: "reload",
      aliases: [],
      glyph: "refresh",
      description: () => I18n.tr("Reload the shell"),
      run: () => Quickshell.reload(false)
    },
    // --- Other searches ---
    root._prefix("calc", ["math"], "calculate", "Calculate (or start with =)", "=", () => LauncherConfig.calculator), root._prefix("run", ["exec", "sh"], "terminal", "Run a shell command (or start with >)", ">", () => LauncherConfig.runCommands), root._prefix("web", ["search"], "web", "Search the web (or start with ?)", "?", () => LauncherConfig.webSearch), root._prefix("help", ["commands"], "help", "List every command", "/", () => true)]

  // --- Builders for families of alike commands ---

  function _session(action, aliases, description) {
    return {
      name: action,
      aliases: aliases,
      glyph: ShellManager.sessionActionInfo(action).icon,
      confirm: ShellManager.destructiveActions.includes(action),
      // I18n.tr("Lock the screen") I18n.tr("Suspend to RAM") I18n.tr("Hibernate to disk")
      // I18n.tr("End the Hyprland session") I18n.tr("Restart the computer") I18n.tr("Turn the computer off")
      description: () => I18n.tr(description),
      run: () => ShellManager.sessionAction(action)
    };
  }

  // Opens the overlay on a page by view type
  function _page(name, aliases, type, description) {
    return {
      name: name,
      aliases: aliases,
      glyph: OverlayConfig.viewInfo(type)?.icon ?? "dashboard",
      // I18n.tr("Open the settings") I18n.tr("Open the themes page") I18n.tr("Open the bar editor")
      // I18n.tr("Show the keybinds") I18n.tr("Open the overlay editor")
      // I18n.tr("Open the edge menu editor")
      description: () => I18n.tr(description),
      run: () => ShellManager.openOverlayPage(type)
    };
  }

  // Picks the default audio device from `nodes()`
  function _device(name, aliases, glyph, description, nodes, current) {
    return {
      name: name,
      aliases: aliases,
      glyph: glyph,
      usage: "<device>",
      needsArg: true,
      // I18n.tr("Choose the audio output") I18n.tr("Choose the audio input")
      description: () => I18n.tr(description),
      status: () => current()?.description ?? "",
      options: () => nodes().map(node => ({
              title: node.description || node.name,
              subtitle: node === current() ? I18n.tr("Current") : "",
              value: node
            })),
      run: (arg, value) => {
        if (value)
          AudioManager.setDefault(value);
        return false;
      }
    };
  }

  function _media(name, aliases, glyph, description, action) {
    return {
      name: name,
      aliases: aliases,
      glyph: glyph,
      // I18n.tr("Play or pause") I18n.tr("Next track") I18n.tr("Previous track")
      description: () => I18n.tr(description),
      available: () => MediaManager.hasActivePlayer,
      status: () => [MediaManager.trackTitle, MediaManager.trackArtist].filter(s => s).join(" · "),
      run: () => {
        action();
        return false;
      }
    };
  }

  // Switches the search to one of the prefixes
  function _prefix(name, aliases, glyph, description, prefix, available) {
    return {
      name: name,
      aliases: aliases,
      glyph: glyph,
      // I18n.tr("Calculate (or start with =)") I18n.tr("Run a shell command (or start with >)")
      // I18n.tr("Search the web (or start with ?)") I18n.tr("List every command")
      description: () => I18n.tr(description),
      available: available,
      run: arg => prefix + arg
    };
  }

  // --- /config ---

  // Every row's title is the whole argument it stands for, since rows are
  // matched against the typed argument and Tab completes to the title
  function _configOptions(arg) {
    const space = arg.indexOf(" ");
    if (space < 0) {
      const rows = [
        {
          title: "save",
          subtitle: I18n.tr("Save the current config under a name"),
          glyph: "save",
          value: {
            next: "save "
          }
        },
        {
          title: "restore",
          subtitle: I18n.tr("Restore a saved config"),
          glyph: "settings_backup_restore",
          value: {
            next: "restore "
          }
        }
      ];
      return rows.concat(SettingsManager.settingPaths.map(entry => ({
            title: entry.key,
            subtitle: I18n.tr(entry.schema.title ?? entry.key) + " · " + root._configShow(SettingsManager.valueOf(entry.key), entry.schema),
            value: {
              next: entry.key + " "
            }
          })));
    }

    const head = arg.slice(0, space);
    const rest = arg.slice(space + 1);
    const names = root._savedConfigNames();
    if (head === "save") {
      const name = SavedConfigsManager.sanitize(rest);
      const rows = name === "" ? [] : [
        {
          title: "save " + rest.trim(),
          subtitle: names.includes(name) ? I18n.tr("Replace \"{0}\"", name) : I18n.tr("Save as \"{0}\"", name),
          value: {
            save: name
          }
        }
      ];
      return rows.concat(names.filter(saved => saved !== name).map(saved => ({
            title: "save " + saved,
            subtitle: I18n.tr("Replace \"{0}\"", saved),
            value: {
              save: saved
            }
          })));
    }
    if (head === "restore")
      return names.map(saved => ({
            title: "restore " + saved,
            value: {
              restore: saved
            }
          }));

    const entry = SettingsManager.settingFor(head);
    if (!entry)
      return [
        {
          title: arg.trim(),
          subtitle: I18n.tr("No setting \"{0}\"", head),
          glyph: "warning",
          value: {}
        }
      ];
    const schema = entry.schema;
    const current = SettingsManager.valueOf(entry.key);
    const choices = schema.type === "boolean" ? ["on", "off"] : schema.type === "string" ? SettingsManager.optionsFor(schema) : null;
    const setRow = (text, parsed) => ({
          title: entry.key + " " + text,
          subtitle: parsed.error ?? (JSON.stringify(parsed.value) === JSON.stringify(current) ? I18n.tr("Current") : I18n.tr("Set {0} to {1} (now {2})", I18n.tr(schema.title ?? entry.key), root._configShow(parsed.value, schema), root._configShow(current, schema))),
          glyph: parsed.error ? "warning" : "",
          value: parsed.error ? {} : {
            key: entry.key,
            set: parsed.value
          }
        });
    const typed = rest.trim();
    if (typed === "" && !choices)
      return [
        {
          title: entry.key,
          subtitle: I18n.tr("Type a value (now {0})", root._configShow(current, schema)),
          value: {
            next: entry.key + " "
          }
        }
      ];
    let rows = [];
    // Typed text that isn't (the start of) a choice gets a row of its own,
    // so free values, and why one is rejected, show
    if (typed !== "" && !(choices ?? []).some(choice => choice.toLowerCase().startsWith(typed.toLowerCase())))
      rows.push(setRow(typed, SettingsManager.parseValue(schema, rest)));
    if (choices)
      rows = rows.concat(choices.map(choice => {
        const text = choice === "" ? "\"\"" : choice;
        return setRow(text, SettingsManager.parseValue(schema, text));
      }));
    return rows;
  }

  function _configRun(value) {
    if (value?.next)
      return "/config " + value.next;
    if (value?.save) {
      SavedConfigsManager.save(value.save);
      return;
    }
    if (value?.restore) {
      SavedConfigsManager.restore(value.restore);
      return;
    }
    if (value?.key !== undefined && !SettingsManager.commitValue(value.key, value.set))
      console.warn("[LauncherCommands] Could not set", value.key);
    return false;
  }

  function _configShow(value, schema) {
    if (schema.type === "boolean")
      return value ? I18n.tr("On") : I18n.tr("Off");
    if (Array.isArray(value))
      return value.length > 0 ? value.join(", ") : I18n.tr("None");
    if (value === "")
      return I18n.tr("Empty");
    return String(value);
  }

  function _savedConfigNames() {
    const names = [];
    const model = SavedConfigsManager.model;
    for (let i = 0; i < model.count; i++)
      names.push(model.get(i, "fileBaseName"));
    return names;
  }

  // --- Option lists ---

  function _onOffOptions() {
    return [
      {
        title: "on",
        value: "on"
      },
      {
        title: "off",
        value: "off"
      }
    ];
  }

  // "on" → true, "off" → false, anything else (a toggle) → null
  function _onOff(arg) {
    const word = (arg ?? "").trim().toLowerCase();
    if (["on", "1", "true", "yes"].includes(word))
      return true;
    if (["off", "0", "false", "no"].includes(word))
      return false;
    return null;
  }

  function _overlayPages() {
    const pages = OverlayConfig.views.map(view => {
      const info = OverlayConfig.viewInfo(view.type);
      return {
        title: view.name || info?.label || view.type,
        subtitle: view.name ? info?.label ?? view.type : "",
        glyph: info?.icon,
        value: view.name || view.type
      };
    });
    return pages.concat([
      {
        title: I18n.tr("Overlay editor"),
        glyph: "dashboard",
        value: "OverlayEditor"
      }
    ]);
  }

  function _wallpapers() {
    const rows = [
      {
        title: I18n.tr("Random"),
        glyph: "shuffle",
        value: "random"
      }
    ];
    const model = ThemeManager.wallpaperModel;
    for (let i = 0; i < model.count; i++)
      rows.push({
        title: model.get(i, "fileBaseName"),
        image: model.get(i, "fileUrl").toString(),
        value: model.get(i, "fileUrl").toString()
      });
    return rows;
  }
}
