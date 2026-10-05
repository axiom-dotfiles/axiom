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

  // "checking" | "checkFailed" (lastError says why) | "noGreetd"
  // (greetd isn't installed) | "off" |
  // "notInstalled" (Greeter.enabled, but no copy: set up by hand, or
  // removed outside axiom) | "outdated" (the copy is behind axiom, or
  // greetd's command was changed) | "installed"
  readonly property string status: {
    const report = root._report;
    if (!report)
      return root._checkFailed ? "checkFailed" : "checking";
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
        root._checkFailed = root._report === null;
        root._lastError = report.error;
        return;
      }
      root._checkFailed = false;
      root._report = report;
      root._notifyOutdated();
    });
  }
  property bool _checking: false
  // The first check failed: nothing is known (a later one keeps the last
  // good report)
  property bool _checkFailed: false

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
  // while it's up (axiom's own draws over everything). Install and update
  // first stage the bundle in the user's runtime folder, which the script
  // snapshots as the copy's fallback; once they're done the bundle itself
  // is written at once, so the greeter never starts before it's there
  function _elevate(action) {
    if (root._elevating)
      return;
    root._elevating = true;
    root._lastError = "";
    const staging = action === "uninstall" ? "" : Paths.runtimePath + "greeter-bundle";
    if (!staging) {
      root._runElevated(action, "");
      return;
    }
    root._writeBundle(staging, false, ok => {
      if (!ok)
        console.warn("[GreeterManager] Staging the login screen's config failed; installing without a fallback");
      root._runElevated(action, ok ? staging : "");
    });
  }

  function _runElevated(action, staging) {
    const external = PolkitManager.status !== "running";
    if (external)
      ShellManager.beginStepAside("greeter");
    const args = ["pkexec", "/usr/bin/bash", root._script, action, Paths.axiomPath, Quickshell.env("USER")].concat(staging ? [staging] : []);
    CommandManager.run(args, (exitCode, out, err) => {
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
        if (action !== "uninstall") {
          root._written = "";
          root._writeBundle(Paths.greeterBundlePath, true, ok => root._written = ok ? root._bundleKey : "");
        }
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
    copies[url] = "wallpapers/" + Qt.md5(url) + extension;
    return copies;
  }, {})
  readonly property string _bundleText: JSON.stringify(GreeterBundle.exportConfig(ConfigManager.config, ConfigManager.configSchema.properties.Hyprland.properties.managed, Object.keys(root._wallpaperCopies).reduce((urls, url) => {
    urls[url] = "file://" + Paths.greeterBundlePath + root._wallpaperCopies[url];
    return urls;
  }, {})), null, 2)
  readonly property string _themeText: JSON.stringify(ThemeManager.currentTheme, null, 2)
  // [source path, copy relative to the bundle] per wallpaper
  readonly property var _wallpaperPairs: [].concat(...root._wallpaperSources.map(url => [decodeURIComponent(url.replace("file://", "")), root._wallpaperCopies[url]]))
  // Everything the bundle holds; written while installed, a moment after it
  // changes
  readonly property string _bundleKey: root._exporting ? [root._bundleText, root._themeText].concat(root._wallpaperPairs).join("\n") : ""
  on_BundleKeyChanged: if (root._bundleKey)
    _exportDelay.restart()

  property Timer _exportDelay: Timer {
    interval: 1000
    onTriggered: root._export()
  }

  // The _bundleKey last written ("" when the last write failed: retried
  // on the next change)
  property string _written: ""

  function _export() {
    const key = root._bundleKey;
    if (!key || key === root._written)
      return;
    root._written = key;
    root._writeBundle(Paths.greeterBundlePath, true, ok => {
      if (!ok && root._written === key)
        root._written = "";
    });
  }

  // Writes the bundle into `dir`: greeter.json and theme.json (each
  // through a temp file and a rename, so the greeter never reads half of
  // one) and, `withWallpapers`, the wallpapers' copies (copied when new or
  // changed; copies no longer used removed). Everything is made readable
  // to greetd's user whatever the umask. then(ok)
  function _writeBundle(dir, withWallpapers, then) {
    CommandManager.run(["sh", "-c", `dir=$1; bundle=$2; theme=$3; shift 3
mkdir -p "$dir" || exit 1
printf '%s\\n' "$bundle" >"$dir/.greeter.json.part" && mv -f -- "$dir/.greeter.json.part" "$dir/greeter.json" || exit 1
printf '%s\\n' "$theme" >"$dir/.theme.json.part" && mv -f -- "$dir/.theme.json.part" "$dir/theme.json" || exit 1
if [ "$1" = "--wallpapers" ]; then
  shift
  mkdir -p "$dir/wallpapers" || exit 1
  keep=""
  while [ $# -ge 2 ]; do
    if [ -f "$1" ] && ! [ "$dir/$2" -nt "$1" ]; then cp -f -- "$1" "$dir/.part" && mv -f -- "$dir/.part" "$dir/$2" || exit 1; fi
    keep="$keep
$dir/$2"; shift 2
  done
  for file in "$dir"/wallpapers/*; do
    [ -e "$file" ] || continue
    printf '%s\\n' "$keep" | grep -Fqx -- "$file" || rm -f -- "$file"
  done
fi
chmod -R go+rX "$dir"`, "sh", dir.replace(/\/$/, ""), root._bundleText, root._themeText].concat(withWallpapers ? ["--wallpapers"].concat(root._wallpaperPairs) : []), (exitCode, out, err) => {
      if (exitCode !== 0)
        console.warn("[GreeterManager] Writing the login screen's config to", dir, "failed:", err.trim());
      then(exitCode === 0);
    });
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
