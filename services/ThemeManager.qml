pragma Singleton

import QtQuick
import Qt.labs.folderlistmodel
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland

import qs.config

/* ThemeManager owns the active theme's data (loaded from its file, watched,
 * with defaults for what it leaves out), the theme lists, theme generation
 * from a wallpaper, the wallpaper itself, and re-theming integrated tools.
 * The choice of theme is config (Appearance.theme), persisted through
 * ConfigManager.setTheme. */
QtObject {
  id: root

  //=========================================================================
  // Public Models & State
  //=========================================================================
  readonly property FolderListModel wallpaperModel: FolderListModel {
    folder: "file://" + Appearance.wallpaperPath
    nameFilters: ["*.jpg", "*.jpeg", "*.png", "*.bmp"]
    showDirs: false
  }
  // One entry per theme, a dark/light pair being one theme:
  // [{ label, dark, light, darkPreview, lightPreview, generated }], where
  // dark/light are Appearance.theme names ("" for a variant the theme doesn't
  // have) and the previews are that variant's _preview (or null). Stock
  // themes first.
  readonly property var themeFamilies: _families
  // The family Appearance.theme belongs to, or null
  readonly property var currentFamily: themeFamilies.find(family => family.dark === Appearance.theme || family.light === Appearance.theme) ?? null
  readonly property bool isGenerating: generationProcess.running

  // The active theme's JSON ({ name, variant, paired, colors, semantic }),
  // read through config/Theme
  readonly property var currentTheme: _theme
  // config/json/theme-defaults.json: fallback palette and semantic maps,
  // shared with scripts/generate_theme.py
  readonly property var defaults: _defaults

  signal generationFailed(string errorText)
  onGenerationFailed: errorText => NotificationManager.sendNotification("axiom", I18n.tr("Failed to generate themes"), I18n.tr("There was an error while processing the wallpaper. Details: {0}", errorText))

  //=========================================================================
  // Public Functions
  //=========================================================================

  // `themeName` as Appearance.theme names it (generated ones "generated/…")
  function applyTheme(themeName) {
    if (!themeName || Appearance.theme === themeName)
      return;
    ConfigManager.setTheme(themeName);
  }

  // A family's variant for the current light/dark mode, or the one it has
  function applyFamily(family) {
    applyTheme(Appearance.darkMode ? (family.dark || family.light) : (family.light || family.dark));
  }

  // Sets the wallpaper, then generates themes from it
  function setWallpaperAndGenerate(wallpaperUrl, monitor) {
    setWallpaper(wallpaperUrl.toString(), monitor);
    generateThemesFromWallpaper(wallpaperUrl);
  }

  // Sets `monitor`'s wallpaper (the focused monitor's without one). The
  // primary monitor's is also Appearance.wallpaper, the lockscreen's.
  function setWallpaper(wallpaperUrl, monitor) {
    if (!wallpaperUrl)
      return;
    const target = monitor || (Hyprland.focusedMonitor?.name ?? General.primaryMonitor);
    const primary = target === General.primaryMonitor;
    _showWallpaper(wallpaperUrl, target, primary);
    ConfigManager.setWallpaper(wallpaperUrl, target, primary);
  }

  // Sets several monitors' wallpapers at once ({ monitor: url }), with one
  // save; true if any changed
  function setWallpapers(wallpapers) {
    const primary = General.primaryMonitor;
    const changed = Object.keys(wallpapers).filter(monitor => wallpapers[monitor] && (Appearance.wallpapers[monitor] !== wallpapers[monitor] || (monitor === primary && Appearance.wallpaper !== wallpapers[monitor])));
    if (changed.length === 0)
      return false;
    for (const monitor of changed)
      _showWallpaper(wallpapers[monitor], monitor, monitor === primary);
    ConfigManager.setWallpapers(changed.reduce((map, monitor) => {
      map[monitor] = wallpapers[monitor];
      return map;
    }, {}), primary);
    return true;
  }

  // Shows the configured wallpaper on every screen without saving anything,
  // for when the config changed under them (a restored snapshot), and
  // brings a generated theme in line with it.
  function applyWallpapers() {
    for (const screen of Quickshell.screens) {
      const url = Appearance.wallpaperFor(screen.name);
      if (!url)
        continue;
      _showWallpaper(url, screen.name, screen.name === General.primaryMonitor);
    }
    syncGeneratedTheme();
  }

  // awww needs telling; the built-in backend (shell/Wallpaper) follows the
  // config. Either way the primary's is linked to ~/.current_wallpaper.
  function _showWallpaper(url, monitor, primary) {
    const path = url.replace("file://", "");
    if (Appearance.wallpaperBackend === "awww")
      Quickshell.execDetached([Paths.scriptsPath + "setWallpaper.sh", path, monitor, primary ? "1" : "0"]);
    else if (primary)
      Quickshell.execDetached(["ln", "-sf", path, Quickshell.env("HOME") + "/.current_wallpaper"]);
  }

  // Generated themes are named by style, not wallpaper, so each run
  // overwrites the last and a config only records the theme's name. When
  // the active one was made from another wallpaper than the configured one
  // (a snapshot restored over a newer generation), generate it again: the
  // file watch then reloads the colors and runs the integrations.
  function syncGeneratedTheme() {
    if (!Appearance.theme.startsWith("generated/") || !Appearance.wallpaper)
      return;
    // Already on its way
    if (isGenerating && (generationProcess.wallpaper === Appearance.wallpaper || root._pendingGeneration === Appearance.wallpaper))
      return;
    const wanted = decodeURIComponent(Appearance.wallpaper.replace("file://", ""));
    if (root.currentTheme?.generated?.wallpaper === wanted)
      return;
    console.log("[ThemeManager] Generated theme is from", root.currentTheme?.generated?.wallpaper ?? "no wallpaper", "- regenerating for", wanted);
    generateThemesFromWallpaper(Appearance.wallpaper);
  }

  // A request made while a run is going replaces any earlier one and runs
  // after it, so the last wallpaper asked for is the one generated
  property string _pendingGeneration: ""

  function generateThemesFromWallpaper(wallpaperUrl) {
    // The one running is the latest wanted again (Dark, Light, Dark):
    // nothing after it
    if (isGenerating && wallpaperUrl.toString() === generationProcess.wallpaper) {
      root._pendingGeneration = "";
      return;
    }
    if (isGenerating) {
      console.log("[ThemeManager] Generation already in progress; queued:", wallpaperUrl.toString());
      root._pendingGeneration = wallpaperUrl.toString();
      return;
    }
    console.log("[ThemeManager] Starting generation process for:", wallpaperUrl.toString());
    generationProcess.start(wallpaperUrl);
  }

  // Switches to the current theme's light (or dark) variant, if it has one
  function setLightMode(light) {
    const target = light ? currentFamily?.light : currentFamily?.dark;
    if (!target) {
      console.log("[ThemeManager] No", light ? "light" : "dark", "variant of", Appearance.theme);
      return;
    }
    applyTheme(target);
  }

  function toggleDarkMode() {
    setLightMode(Appearance.darkMode);
  }

  // Runs the enabled integrations (scripts/theme_<key>.sh, one per
  // ThemeIntegrations switch) for a theme; `keys` limits it to those (none:
  // all of them)
  function themeIntegrations(themeName = Appearance.theme, keys = []) {
    const themePath = Paths.themePath + themeName + ".json";
    const all = keys.length === 0;
    if (all && LockscreenConfig.mode === "hyprlock")
      root.generateHyprlockConfig();
    for (let i = 0; i < root.integrations.length; i++) {
      const key = root.integrations[i];
      const process = root._integrationRunner.objectAt(i);
      if (!ThemeIntegrations[key] || !process || (!all && !keys.includes(key)))
        continue;
      // A busy one runs again for the latest theme once it's done, or a
      // quick light-dark-light would leave it on the middle one
      if (process.running) {
        process.queued = themePath;
        continue;
      }
      process.command = [Paths.scriptsPath + "theme_" + key + ".sh", themePath];
      process.running = true;
    }
    if (all)
      root._themed = root._enabledIntegrations;
  }

  // The switched-on integrations (keys, in schema order), and those as of the
  // last full run (null before the first, while config and theme load):
  // one switched on since is themed right away, not at the next theme
  // change
  readonly property var _enabledIntegrations: root.integrations.filter(key => ThemeIntegrations[key] === true)
  property var _themed: null
  on_EnabledIntegrationsChanged: {
    if (root._themed === null)
      return;
    const added = root._enabledIntegrations.filter(key => !root._themed.includes(key));
    root._themed = root._enabledIntegrations;
    if (added.length > 0)
      root.themeIntegrations(Appearance.theme, added);
  }

  // The themed hyprlock config (Lockscreen.mode "hyprlock"): the theme's
  // colors plus the font, wallpaper and a translated greeting. `then` runs
  // once it's written (LockManager locks with it).
  function generateHyprlockConfig(then) {
    if (then)
      root._hyprlockThen.push(then);
    if (root._hyprlockProcess.running) {
      root._hyprlockAgain = true;
      return;
    }
    root._hyprlockProcess.command = [Paths.scriptsPath + "theme_hyprlock.sh", Paths.themePath + Appearance.theme + ".json", LockManager.hyprlockConfigPath, Appearance.fontFamily, Appearance.wallpaper, LockscreenConfig.blurWallpaper ? "1" : "0", I18n.tr("Hey {0}", General.displayName), I18n.tr("Enter password...")];
    root._hyprlockProcess.running = true;
  }

  //=========================================================================
  // Private Implementation
  //=========================================================================
  Component.onCompleted: {
    // What the initializer loaded, so the first change check is a no-op
    root._themeContent = FileManager.read(root._themeUrl(root._themeName)) ?? "";
    root._loadedName = root._themeName;
    // Keep the initial value but drop its binding, which would re-read the
    // file on every config save (mid-write during a generation);
    // _reloadTheme owns it from here
    const initial = root._theme;
    root._theme = initial;
    _reloadAllThemes();
    if (!root._themeContent)
      syncGeneratedTheme();
  }

  // --- Active theme ---
  // Loaded eagerly so config/Theme never sees an empty theme
  property var _defaults: _readDefaults()
  property var _theme: _parseTheme(FileManager.read(_themeUrl(ConfigManager.config.Appearance.theme)), ConfigManager.config.Appearance.theme)
  property string _themeContent: ""
  // The theme _theme and _themeContent are from
  property string _loadedName: ""
  readonly property string _themeName: ConfigManager.config.Appearance.theme
  on_ThemeNameChanged: _reloadTheme()

  property FileView _themeWatch: FileView {
    path: root._themeUrl(root._themeName)
    watchChanges: true
    printErrors: false
    onFileChanged: {
      reload();
      root._reloadTheme();
    }
  }

  function _themeUrl(name) {
    return "file://" + Paths.themePath + name + ".json";
  }

  function _readDefaults() {
    try {
      return JSON.parse(FileManager.read("file://" + Paths.configPath + "json/theme-defaults.json"));
    } catch (e) {
      console.error("[ThemeManager] Could not read theme-defaults.json:", e);
      return {
        "colors": {},
        "semantic": {
          "dark": {},
          "light": {}
        }
      };
    }
  }

  // A theme file's JSON, or null if it's empty or broken
  function _tryParse(content) {
    if (!content)
      return null;
    try {
      return JSON.parse(content);
    } catch (e) {
      return null;
    }
  }

  // A theme file's JSON, or the default palette if it's missing or broken,
  // in the variant its name suggests (so a missing light theme doesn't
  // turn Appearance.darkMode on)
  function _parseTheme(content, name) {
    const parsed = _tryParse(content);
    if (parsed)
      return parsed;
    console.error("[ThemeManager]", content ? "Failed to parse theme:" : "Theme not found:", name);
    const defaults = root._defaults ?? _readDefaults();
    const variant = /light$/i.test(name ?? "") ? "light" : "dark";
    return {
      "name": "Default (fallback)",
      "variant": variant,
      "colors": defaults.colors,
      "semantic": defaults.semantic[variant]
    };
  }

  // Reloads the active theme when its name or its file's contents change,
  // and re-themes the integrated tools (not on startup)
  function _reloadTheme() {
    const name = _themeName;
    const content = FileManager.read(_themeUrl(name)) ?? "";
    if (name === _loadedName && content === _themeContent)
      return;
    // Mid-write: generate_theme.py (or an editor) truncates a file before
    // writing it, and the watch fires in between. Keep what's showing: the
    // next change, or the end of the generation, reads it whole. Falling
    // back here would flash the default palette and flip darkMode.
    if (!_tryParse(content) && (name === _loadedName || isGenerating)) {
      console.log("[ThemeManager]", name, "is empty or partly written; keeping the current colors");
      return;
    }
    _loadedName = name;
    _themeContent = content;
    _theme = _parseTheme(content, name);
    // A generated theme that isn't there yet (a migrated name, a cleared
    // folder) is made, and themes the tools once it's read
    if (!content) {
      syncGeneratedTheme();
      return;
    }
    // Deferred: a restored config changes the theme and the integration
    // switches at once, and ThemeIntegrations may not have caught up yet
    Qt.callLater(root.themeIntegrations);
  }

  // --- Paths and Models ---
  readonly property string _themesPath: "file://" + Paths.themePath
  readonly property string _generatedThemesPath: "file://" + Paths.themePath + "generated"
  readonly property string _pythonScriptPath: Paths.scriptsPath + "generate_theme.py"

  // Each folder's themes, [{ name, label, variant, paired }], combined
  // into _families once either folder has been scanned
  property var _stockThemes: []
  property var _generatedThemes: []
  property var _families: []

  // --- Integration processes ---

  // The ThemeIntegrations switches, in schema order: one per
  // scripts/theme_<key>.sh
  readonly property var integrations: {
    const props = ConfigManager.configSchema.properties.ThemeIntegrations.properties;
    return Object.keys(props).filter(key => props[key].type === "boolean");
  }

  // An integration's name (its schema title, untranslated)
  function integrationTitle(key) {
    return ConfigManager.configSchema.properties.ThemeIntegrations.properties[key]?.title ?? key;
  }

  // The commands any of which shows an integration's app is installed: its
  // key unless listed here, none for ones every desktop has
  readonly property var _integrationCommands: ({
      "gtk": [],
      "qt": ["qt6ct", "qt5ct"],
      "helix": ["hx", "helix"],
      "vscode": ["code", "codium"],
      "vesktop": ["vesktop", "dev.vencord.Vesktop", "equibop", "discord"],
      "firefox": ["firefox", "librewolf", "zen-browser", "zen", "floorp", "waterfox", "org.mozilla.firefox", "io.gitlab.librewolf-community", "app.zen_browser.zen", "one.ablaze.floorp", "net.waterfox.waterfox"]
    })
  function integrationCommands(key) {
    return root._integrationCommands[key] ?? [key];
  }

  // One process per integration, each running its script
  property Instantiator _integrationRunner: Instantiator {
    model: root.integrations
    delegate: Process {
      id: integration
      required property string modelData
      // Reported once both the exit and the end of stderr are in, in
      // whichever order they come
      property int _exitCode: -1
      property bool _stderrDone: false
      // A theme asked for while it was running, run next
      property string queued: ""

      function _report() {
        if (_exitCode < 0 || !_stderrDone)
          return;
        // A failure logs all of stderr; a success only its "Warning:" lines
        const text = errors.text.trim();
        const shown = _exitCode === 0 ? text.split("\n").filter(line => line.startsWith("Warning:")).join("\n") : text || "exited with " + _exitCode;
        if (shown)
          console.warn("[ThemeManager] theme_" + modelData + ".sh:", shown);
        if (queued) {
          command = [Paths.scriptsPath + "theme_" + modelData + ".sh", queued];
          queued = "";
          Qt.callLater(() => integration.running = true);
        }
      }

      onRunningChanged: if (running) {
        _exitCode = -1;
        _stderrDone = false;
      }
      onExited: exitCode => {
        _exitCode = exitCode;
        _report();
      }
      stdout: StdioCollector {}
      stderr: StdioCollector {
        id: errors
        onStreamFinished: {
          integration._stderrDone = true;
          integration._report();
        }
      }
    }
  }

  // Everything besides the theme that goes into the hyprlock config
  readonly property string _hyprlockInputs: [Appearance.fontFamily, Appearance.wallpaper, LockscreenConfig.blurWallpaper, I18n.language, General.displayName].join("|")
  on_HyprlockInputsChanged: if (LockscreenConfig.mode === "hyprlock")
    root.generateHyprlockConfig()

  property var _hyprlockThen: []
  property bool _hyprlockAgain: false
  property Process _hyprlockProcess: Process {
    stdout: StdioCollector {}
    stderr: StdioCollector {
      onStreamFinished: if (text.trim())
        console.warn("[ThemeManager] theme_hyprlock.sh:", text.trim())
    }
    onExited: exitCode => {
      if (root._hyprlockAgain) {
        root._hyprlockAgain = false;
        root.generateHyprlockConfig();
        return;
      }
      const callbacks = root._hyprlockThen;
      root._hyprlockThen = [];
      if (exitCode === 0)
        callbacks.forEach(then => then());
    }
  }

  // --- Generation Logic ---
  // One run generates every style's pair (generate_theme.py STYLES).
  // venv_python.sh sets up (or updates) the venv first.

  property Process _generationProcess: Process {
    id: generationProcess

    // The URL being generated from
    property string wallpaper: ""

    function start(wallpaperUrl) {
      wallpaper = wallpaperUrl.toString();
      const wallpaperPath = wallpaperUrl.toString().replace("file://", "");
      command = [Paths.scriptsPath + "venv_python.sh", root._pythonScriptPath, wallpaperPath, "--output_dir", Paths.themePath + "generated"];
      console.log("[ThemeManager] Executing:", command.join(" "));
      running = true;
    }

    stdout: StdioCollector {
      onStreamFinished: if (text.trim())
        console.log("[ThemeManager] generate_theme.py:", text.trim())
    }
    stderr: StdioCollector {
      id: stderrCollector
    }
    onExited: (exitCode, exitStatus) => {
      const errors = stderrCollector.text.trim();
      if (exitStatus !== 0 || exitCode !== 0) {
        console.error("[ThemeManager] Theme generation failed.", errors);
        root.generationFailed(errors);
      } else {
        // The venv was set up
        if (errors)
          console.warn("[ThemeManager] generate_theme.py:", errors);
        console.log("[ThemeManager] Theme generation finished successfully.");
        root._reloadAllThemes();
        // The watch misses a file that didn't exist when it started
        root._reloadTheme();
      }
      const next = root._pendingGeneration;
      root._pendingGeneration = "";
      if (next)
        Qt.callLater(() => root.generateThemesFromWallpaper(next));
    }
  }

  // --- Theme List Loading ---

  // Rescans both theme folders; each rebuilds the families when it's read
  function _reloadAllThemes() {
    _defaultThemeLoader.folder = "";
    _generatedThemeLoader.folder = "";
    _defaultThemeLoader.folder = _themesPath;
    _generatedThemeLoader.folder = _generatedThemesPath;
  }

  // A scanned folder's themes, parsed for their name, variant and pair.
  // `prefix` makes each name what Appearance.theme calls it.
  function _readThemes(loader, prefix) {
    const themes = [];
    for (let i = 0; i < loader.count; i++) {
      const fileName = loader.get(i, "fileName");
      if (fileName === "theme.schema.json")
        continue;
      try {
        const json = JSON.parse(FileManager.read("file://" + loader.get(i, "filePath")));
        themes.push({
          "name": prefix + loader.get(i, "fileBaseName"),
          "label": json.name || loader.get(i, "fileBaseName"),
          "variant": json.variant === "light" ? "light" : "dark",
          "paired": json.paired ? prefix + json.paired : "",
          "preview": root._preview(json)
        });
      } catch (e) {
        console.warn("[ThemeManager] Skipping unreadable theme", fileName, e);
      }
    }
    return themes;
  }

  // A theme's look for the theme list: { background, foreground, accent,
  // colors: base08-base0E }, filling what it omits from theme-defaults.json
  function _preview(json) {
    const variant = json.variant === "light" ? "light" : "dark";
    const colors = Object.assign({}, root._defaults.colors, json.colors ?? {});
    const semantic = Object.assign({}, root._defaults.semantic?.[variant] ?? {}, json.semantic ?? {});
    const resolve = key => colors[semantic[key]] ?? "";
    return {
      "background": resolve("background") || colors.base00,
      "foreground": resolve("foreground") || colors.base05,
      "accent": resolve("accent") || colors.base0D,
      "colors": ["base08", "base09", "base0A", "base0B", "base0C", "base0D", "base0E"].map(name => colors[name])
    };
  }

  // Groups themes with the pair they name, when that pair names them back
  // with the other variant. A pair is labelled by the words its themes'
  // names share ("Tokyo Night" + "Tokyo Day" = "Tokyo").
  function _buildFamilies(themes, generated) {
    const byName = themes.reduce((map, theme) => {
      map[theme.name] = theme;
      return map;
    }, {});
    const seen = {};
    const families = [];
    for (const theme of themes) {
      if (seen[theme.name])
        continue;
      seen[theme.name] = true;
      const pair = byName[theme.paired];
      const paired = pair && !seen[pair.name] && pair.paired === theme.name && pair.variant !== theme.variant;
      if (paired)
        seen[pair.name] = true;
      const dark = theme.variant === "dark" ? theme : (paired ? pair : null);
      const light = theme.variant === "light" ? theme : (paired ? pair : null);
      families.push({
        "label": paired ? _commonLabel(dark.label, light.label) : theme.label,
        "dark": dark?.name ?? "",
        "light": light?.name ?? "",
        "darkPreview": dark?.preview ?? null,
        "lightPreview": light?.preview ?? null,
        "generated": generated
      });
    }
    return families.sort((a, b) => a.label.localeCompare(b.label));
  }

  function _commonLabel(a, b) {
    const wordsA = a.split(" ");
    const wordsB = b.split(" ");
    let n = 0;
    while (n < wordsA.length && n < wordsB.length && wordsA[n] === wordsB[n])
      n++;
    return n > 0 ? wordsA.slice(0, n).join(" ") : a;
  }

  function _rebuildFamilies() {
    root._families = _buildFamilies(root._stockThemes, false).concat(_buildFamilies(root._generatedThemes, true));
    console.log("[ThemeManager] Themes:", root._families.map(family => family.label).join(", "));
  }

  // Ready is reported once before the rows arrive, then again with them.
  // Directories are hidden (showDirs), so "generated" isn't listed.
  property FolderListModel _defaultThemeLoader: FolderListModel {
    nameFilters: ["*.json"]
    showDirs: false
    onStatusChanged: if (status === FolderListModel.Ready && count > 0) {
      root._stockThemes = root._readThemes(root._defaultThemeLoader, "");
      root._rebuildFamilies();
    }
  }

  property FolderListModel _generatedThemeLoader: FolderListModel {
    nameFilters: ["*.json"]
    showDirs: false
    onStatusChanged: if (status === FolderListModel.Ready && count > 0) {
      root._generatedThemes = root._readThemes(root._generatedThemeLoader, "generated/");
      root._rebuildFamilies();
      // Pairs from before styles (one per pywal backend): a run replaces
      // them with every style's, and removes them, so this happens once
      if (Appearance.wallpaper && root._generatedThemes.some(theme => theme.name.startsWith("generated/pywal-")))
        root.generateThemesFromWallpaper(Appearance.wallpaper);
    }
  }
}
