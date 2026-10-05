pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

import qs.config
import qs.components.methods

// Axiom as greetd's login screen, from the user's side (the greeter itself
// is greeter.qml, with GreetdManager). The greeter runs as greetd's user,
// who can't read the user's home, so:
//   - a copy of axiom made for it, owned by root (install/update/uninstall:
//     scripts/greeter/greeter_install.sh through pkexec, one polkit prompt
//     each). A change to axiom's code reaches the greeter only through
//     update(), so a copy behind the repo is `outdated`, notified once per
//     version (clicking it opens Settings → Login screen)
//   - the bundle: what the greeter shows (GreeterBundle.exportConfig: the
//     Greeter section, the look, the monitor layouts and, in managed mode,
//     the Hyprland options marked x-greeter, plus the theme and copies of
//     the wallpapers), exported to a folder of the user's whenever it
//     changes, so changing the login screen needs no root
//   - the layouts editor's draft of its layout (`editor`) and its preview
// Created from shell.qml's _services.
QtObject {
  id: root

  // --- The layout (Greeter.layout) and its preview ---

  property ScreenLayoutEditor editor: ScreenLayoutEditor {
    path: ["Greeter", "layout"]
    host: "greeter"
    name: I18n.tr("Login screen")
  }

  // --- What's set up ---

  // The last `check`: { greetd, displayManager, installed, configured,
  // installedHash, currentHash, greeterUser, bundleWritable, error }, or
  // null before the first
  readonly property var report: _report
  property var _report: null

  // "checking" | "noGreetd" (greetd isn't installed) | "off" |
  // "notInstalled" (Greeter.enabled, but no copy: set up by hand, or
  // removed outside axiom) | "outdated" (the copy is behind axiom, or
  // greetd's command was changed) | "installed"
  readonly property string status: {
    const report = root._report;
    if (!report)
      return "checking";
    if (!report.greetd)
      return "noGreetd";
    if (!report.installed)
      return GreeterConfig.enabled ? "notInstalled" : "off";
    if (!report.configured || report.installedHash !== report.currentHash)
      return "outdated";
    return "installed";
  }

  // pkexec is running (install, update or uninstall)
  readonly property bool elevating: _elevating
  property bool _elevating: false
  // What the last install, update or uninstall said went wrong ("" when
  // it worked)
  readonly property string lastError: _lastError
  property string _lastError: ""

  // What the user still runs for greetd to show the greeter: another
  // display manager disabled and greetd enabled. [] once greetd is the
  // display manager (it takes effect at the next login)
  readonly property var finishCommands: {
    const report = root._report;
    if (!report?.installed || report.displayManager === "greetd")
      return [];
    const commands = report.displayManager ? [`sudo systemctl disable ${report.displayManager}.service`] : [];
    return commands.concat(["sudo systemctl enable greetd.service"]);
  }

  function check() {
    if (root._checking)
      return;
    root._checking = true;
    CommandManager.run(["bash", root._script, "check", Paths.axiomPath], (exitCode, out) => {
      root._checking = false;
      const report = root._parse(out);
      if (report.error) {
        console.warn("[GreeterManager] check:", report.error);
        return;
      }
      root._report = report;
      root._notifyOutdated();
    });
  }
  property bool _checking: false

  function install() {
    root._elevate("install");
  }

  function update() {
    root._elevate("update");
  }

  function uninstall() {
    root._elevate("uninstall");
  }

  function openSettings() {
    SettingsManager.openSection("Greeter");
  }

  // --- Private ---

  readonly property string _script: Paths.scriptsPath + "greeter/greeter_install.sh"
  readonly property string _desktopEntry: "axiom-greeter-update"

  function _parse(text) {
    try {
      return JSON.parse(text.trim());
    } catch (e) {
      return {
        "error": text.trim() || "no output"
      };
    }
  }

  // One polkit prompt for the script as root. Another agent's prompt is an
  // ordinary window, under the overlay and the onboarder: they step aside
  // while it's up (axiom's own draws over everything)
  function _elevate(action) {
    if (root._elevating)
      return;
    // Install snapshots the bundle as the copy's fallback: brought up to
    // date first
    root._export();
    root._elevating = true;
    root._lastError = "";
    const external = PolkitManager.status !== "running";
    if (external)
      ShellManager.beginStepAside("greeter");
    CommandManager.run(["pkexec", "/usr/bin/bash", root._script, action, Paths.axiomPath, Quickshell.env("USER")], (exitCode, out, err) => {
      ShellManager.endStepAside("greeter");
      root._elevating = false;
      const result = root._parse(out);
      if (exitCode !== 0 || result.ok !== true) {
        // pkexec: 126 dismissed, 127 not authorized or not there
        // The script's own error when it ran, else pkexec's (no agent)
        const scriptError = out.trim() ? result.error : "";
        root._lastError = exitCode === 126 ? I18n.tr("The password prompt was dismissed.") : scriptError || err.trim() || I18n.tr("pkexec failed ({0}).", exitCode);
        console.warn("[GreeterManager]", action, "failed:", root._lastError);
      } else {
        console.log("[GreeterManager]", action, "changed", (result.changed ?? []).join(", "), result.backup ? "(backup: " + result.backup + ")" : "");
        if (action === "install" && !GreeterConfig.enabled)
          SettingsManager.commitValues({
            "Greeter.enabled": true
          });
        else if (action === "uninstall" && GreeterConfig.enabled)
          SettingsManager.commitValues({
            "Greeter.enabled": false
          });
      }
      root.check();
    });
  }

  // --- Update notification ---

  property var _state: StateManager.createStateHandler("greeterUpdates")
  // { notifiedHash }: each version of axiom the copy is behind is notified
  // once
  property var _saved: ({})

  function _notifyOutdated() {
    const hash = root._report?.currentHash ?? "";
    if (root.status !== "outdated" || !GreeterConfig.enabled || !hash || root._saved.notifiedHash === hash)
      return;
    NotificationManager.sendNotification("axiom", I18n.tr("Login screen update"), I18n.tr("Axiom changed since its login screen was set up. Click to update it (it asks for your password)."), {
      "desktopEntry": root._desktopEntry
    });
    root._saved = Object.assign({}, root._saved, {
      "notifiedHash": hash
    });
    root._state.save(root._saved);
  }

  // --- The bundle ---

  readonly property bool _exporting: root._report?.installed === true && root._report.bundleWritable === true
  readonly property var _wallpaperSources: GreeterBundle.wallpaperSources(ConfigManager.config)
  // Each wallpaper's copy in the bundle, named by its url
  readonly property var _wallpaperCopies: root._wallpaperSources.reduce((copies, url) => {
    const extension = (url.match(/\.[A-Za-z0-9]+$/) ?? [""])[0].toLowerCase();
    copies[url] = "file://" + Paths.greeterBundlePath + "wallpapers/" + Qt.md5(url) + extension;
    return copies;
  }, {})
  readonly property string _bundleText: JSON.stringify(GreeterBundle.exportConfig(ConfigManager.config, ConfigManager.configSchema.properties.Hyprland.properties.managed, root._wallpaperCopies), null, 2)
  readonly property string _themeText: JSON.stringify(ThemeManager.currentTheme, null, 2)
  // Written while installed, a moment after any of it changes
  readonly property string _exportKey: root._exporting ? root._bundleText + root._themeText : ""
  on_ExportKeyChanged: if (root._exportKey)
    _exportDelay.restart()

  property Timer _exportDelay: Timer {
    interval: 1000
    onTriggered: root._export()
  }

  property string _writtenBundle: ""
  property string _writtenTheme: ""
  property string _writtenWallpapers: ""

  function _export() {
    if (!root._exporting)
      return;
    if (root._bundleText !== root._writtenBundle) {
      _bundleFile.setText(root._bundleText);
      root._writtenBundle = root._bundleText;
    }
    if (root._themeText !== root._writtenTheme) {
      _themeFile.setText(root._themeText);
      root._writtenTheme = root._themeText;
    }
    // Copied when new or changed (cp + mv, so the greeter never reads half
    // of one); copies no longer used are removed
    const pairs = [].concat(...root._wallpaperSources.map(url => [decodeURIComponent(url.replace("file://", "")), root._wallpaperCopies[url].replace("file://", "")]));
    const key = pairs.join("\n");
    if (key === root._writtenWallpapers)
      return;
    root._writtenWallpapers = key;
    CommandManager.run(["sh", "-c", `dir=$1; shift; mkdir -p "$dir" || exit 1
keep=""
while [ $# -ge 2 ]; do
  if [ -f "$1" ] && ! [ "$2" -nt "$1" ]; then cp -f -- "$1" "$dir/.part" && mv -f -- "$dir/.part" "$2"; fi
  keep="$keep
$2"; shift 2
done
for file in "$dir"/*; do
  [ -e "$file" ] || continue
  printf '%s\\n' "$keep" | grep -Fqx -- "$file" || rm -f -- "$file"
done`, "sh", Paths.greeterBundlePath + "wallpapers"].concat(pairs), (exitCode, out, err) => {
      if (exitCode !== 0)
        console.warn("[GreeterManager] Copying wallpapers for the login screen failed:", err.trim());
    });
  }

  property FileView _bundleFile: FileView {
    path: "file://" + Paths.greeterBundlePath + "greeter.json"
    blockWrites: true
    atomicWrites: true
    printErrors: false
    onSaveFailed: error => console.warn("[GreeterManager] Writing the login screen's config failed:", FileViewError.toString(error))
  }

  property FileView _themeFile: FileView {
    path: "file://" + Paths.greeterBundlePath + "theme.json"
    blockWrites: true
    atomicWrites: true
    printErrors: false
    onSaveFailed: error => console.warn("[GreeterManager] Writing the login screen's theme failed:", FileViewError.toString(error))
  }

  // --- Startup ---

  // A little after startup: the hash reads every file axiom ships
  property Timer _startup: Timer {
    interval: 5000
    running: true
    onTriggered: root.check()
  }

  Component.onCompleted: {
    root._saved = root._state.load({});
    NotificationManager.registerHandler(root._desktopEntry, () => root.openSettings());
  }

  property IpcHandler _ipc: IpcHandler {
    target: "greeter"

    // Settings → Login screen
    function open(): void {
      root.openSettings();
    }

    // The layout's draft on screen, as the layouts editor's Show on screen
    function preview(): void {
      root.editor.startPreview();
    }
  }
}
