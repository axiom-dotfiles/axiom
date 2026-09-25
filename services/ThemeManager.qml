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
  onGenerationFailed: errorText => NotificationManager.sendNotification(I18n.tr("Theme Generation"), I18n.tr("Failed to generate themes"), I18n.tr("There was an error while processing the wallpaper. Details: {0}", errorText), {})

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
    Quickshell.execDetached([Paths.scriptsPath + "setWallpaper.sh", wallpaperUrl.replace("file://", ""), target, primary ? "1" : "0"]);
    ConfigManager.setWallpaper(wallpaperUrl, target, primary);
  }

  // Shows the configured wallpaper on every screen without saving anything,
  // for when the config changed under them (a restored snapshot), and
  // brings a generated theme in line with it.
  function applyWallpapers() {
    for (const screen of Quickshell.screens) {
      const url = Appearance.wallpaperFor(screen.name);
      if (!url)
        continue;
      Quickshell.execDetached([Paths.scriptsPath + "setWallpaper.sh", url.replace("file://", ""), screen.name, screen.name === General.primaryMonitor ? "1" : "0"]);
    }
    syncGeneratedTheme();
  }

  // Generated themes are named by backend, not wallpaper, so each run
  // overwrites the last and a config only records the theme's name. When
  // the active one was made from another wallpaper than the configured one
  // (a snapshot restored over a newer generation), generate it again: the
  // file watch then reloads the colors and runs the integrations.
  function syncGeneratedTheme() {
    if (!Appearance.theme.startsWith("generated/") || !Appearance.wallpaper)
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
  // ThemeIntegrations switch) for a theme
  function themeIntegrations(themeName = Appearance.theme) {
    const themePath = Paths.themePath + themeName + ".json";
    if (LockscreenConfig.mode === "hyprlock")
      root.generateHyprlockConfig();
    for (let i = 0; i < root._integrations.length; i++) {
      const key = root._integrations[i];
      const process = root._integrationRunner.objectAt(i);
      // A busy integration only skips itself, not the ones after it
      if (!ThemeIntegrations[key] || !process || process.running)
        continue;
      process.command = [Paths.scriptsPath + "theme_" + key + ".sh", themePath];
      process.running = true;
    }
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
    _reloadAllThemes();
  }

  // --- Active theme ---
  // Loaded eagerly so config/Theme never sees an empty theme
  property var _defaults: _readDefaults()
  property var _theme: _parseTheme(FileManager.read(_themeUrl(ConfigManager.config.Appearance.theme)), ConfigManager.config.Appearance.theme)
  property string _themeContent: ""
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

  // A theme file's JSON, or the default palette if it's missing or broken
  function _parseTheme(content, name) {
    if (content) {
      try {
        return JSON.parse(content);
      } catch (e) {
        console.error("[ThemeManager] Failed to parse theme:", name, e);
      }
    } else {
      console.error("[ThemeManager] Theme not found:", name);
    }
    const defaults = root._defaults ?? _readDefaults();
    return {
      "name": "Default (fallback)",
      "variant": "dark",
      "colors": defaults.colors,
      "semantic": defaults.semantic.dark
    };
  }

  // Reloads the active theme when its name or its file's contents change,
  // and re-themes the integrated tools (not on startup)
  function _reloadTheme() {
    const content = FileManager.read(_themeUrl(_themeName)) ?? "";
    if (content === _themeContent)
      return;
    _themeContent = content;
    _theme = _parseTheme(content, _themeName);
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
  // One per ThemeIntegrations key, each running scripts/theme_<key>.sh
  readonly property var _integrations: ["gtk", "qt", "kitty", "alacritty", "foot", "wezterm", "ghostty", "nvim", "helix", "vscode", "k9s", "cava", "btop", "fzf", "lazygit", "bat", "yazi"]
  property Instantiator _integrationRunner: Instantiator {
    model: root._integrations
    delegate: Process {
      id: integration
      required property string modelData
      // Reported once both the exit and the end of stderr are in, in
      // whichever order they come
      property int _exitCode: -1
      property bool _stderrDone: false

      function _report() {
        if (_exitCode < 0 || !_stderrDone)
          return;
        // A failure logs all of stderr; a success only its "Warning:" lines
        const text = errors.text.trim();
        const shown = _exitCode === 0 ? text.split("\n").filter(line => line.startsWith("Warning:")).join("\n") : text || "exited with " + _exitCode;
        if (shown)
          console.warn("[ThemeManager] theme_" + modelData + ".sh:", shown);
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
  // One run generates every backend's pair; it fails only if all of them do.
  // venv_python.sh sets up (or updates) the venv first.
  readonly property var _generationBackends: ["wal", "colorz", "colorthief", "haishoku"]

  property Process _generationProcess: Process {
    id: generationProcess

    function start(wallpaperUrl) {
      const wallpaperPath = wallpaperUrl.toString().replace("file://", "");
      command = [Paths.scriptsPath + "venv_python.sh", root._pythonScriptPath, wallpaperPath, "--output_dir", Paths.themePath + "generated", "--backend", ...root._generationBackends];
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
        // Some backends failed, or the venv was set up
        if (errors)
          console.warn("[ThemeManager] generate_theme.py:", errors);
        console.log("[ThemeManager] Theme generation finished successfully.");
        root._reloadAllThemes();
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
    }
  }
}
