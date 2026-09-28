pragma Singleton

import QtQuick
import Quickshell.Hyprland
import Quickshell.Io

import qs.config
import qs.components.methods

/*
 * The Monitors page: the connected outputs (`hyprctl monitors all -j`, read
 * at startup and when monitors come, go or the config reloads; never
 * polled) and the editor for Hyprland.monitors, a draft of profiles (each a
 * layout for one set of monitors). HyprlandConfigManager writes the saved
 * profiles into axiom's Lua layer in every mode, where the one matching
 * what's connected applies (again on every hotplug).
 *
 * Apply tries the selected profile at once (hl.monitor through hyprctl
 * eval) and asks to keep it: keep() saves the draft, and revert() (or the
 * countdown running out) puts back what was there before.
 */
QtObject {
  id: root

  // `hyprctl monitors all -j`, disabled ones included
  property var outputs: []
  readonly property var enabledOutputs: outputs.filter(monitor => !monitor.disabled)

  // --- The draft ---

  property ConfigDraft _draft: ConfigDraft {
    id: draft
    path: ["Hyprland", "monitors"]
  }
  readonly property var profiles: draft.local?.profiles ?? []
  readonly property alias isDirty: draft.isDirty

  // The profile shown on the page
  property int selectedProfile: 0
  readonly property var profile: profiles[selectedProfile] ?? null
  readonly property var rules: profile?.outputs ?? []
  // The selected output (its rule's `output`)
  property string selectedOutput: ""
  readonly property int selectedIndex: rules.findIndex(rule => rule.output === selectedOutput)
  readonly property var selectedRule: rules[selectedIndex] ?? null

  // The saved profile Hyprland is using now, and the draft's
  readonly property int activeProfile: MonitorLayout.matchProfile(HyprlandConfig.monitorProfiles, enabledOutputs)
  readonly property int liveProfile: MonitorLayout.matchProfile(profiles, enabledOutputs)
  // The selected profile is for what's connected: Apply tries it live
  readonly property bool selectedIsLive: selectedProfile === liveProfile

  // Loads the draft unless it holds unsaved edits (the page is rebuilt
  // whenever the overlay reopens), with a profile for what's connected
  function ensureLoaded() {
    if (!draft.isDirty) {
      draft.load();
      _detectPending = true;
    }
    refresh();
  }

  // Detect once the monitors have been read
  property bool _detectPending: false
  // The page is open: a monitor coming or going re-detects (unless edited)
  property bool pageShown: false
  // The inspector's Advanced section is unfolded
  property bool advancedOpen: false

  function save() {
    draft.save();
  }

  function reset() {
    draft.load();
    _detect();
  }

  onOutputsChanged: {
    if (_detectPending && outputs.length > 0) {
      _detectPending = false;
      _detect();
    }
  }

  // The connected monitor a rule is for, or null
  function monitorFor(rule) {
    return rule ? MonitorLayout.find(rule.output, outputs) : null;
  }

  // A rule's rect in the layout
  function rectFor(rule) {
    return MonitorLayout.ruleRect(rule, monitorFor(rule));
  }

  // What's connected, as a profile: the selected one when it's for these
  // monitors (adding any it doesn't list), else a new one from how they are
  function _detect() {
    if (outputs.length === 0)
      return;
    const local = draft.local ?? {
      "profiles": []
    };
    draft.local = local;
    local.profiles = local.profiles ?? [];
    let index = MonitorLayout.matchProfile(local.profiles, enabledOutputs);
    let edited = false;
    if (index < 0) {
      local.profiles.push({
        "name": _uniqueName(I18n.tr("Layout {0}", local.profiles.length + 1)),
        "outputs": outputs.map(monitor => MonitorLayout.ruleFromMonitor(monitor, outputs))
      });
      index = local.profiles.length - 1;
      edited = true;
    } else {
      const listed = local.profiles[index].outputs;
      for (const monitor of outputs)
        if (!listed.some(rule => MonitorLayout.matches(rule.output, monitor))) {
          listed.push(MonitorLayout.ruleFromMonitor(monitor, outputs));
          edited = true;
        }
    }
    selectedProfile = index;
    if (selectedIndex < 0)
      selectedOutput = local.profiles[index].outputs[0]?.output ?? "";
    if (edited)
      draft.changed();
  }

  function _uniqueName(name) {
    let result = name;
    for (let n = 2; profiles.some(profile => profile.name === result); n++)
      result = `${name} (${n})`;
    return result;
  }

  // --- Editing ---

  function setField(output, key, value) {
    const rule = draft.local?.profiles?.[selectedProfile]?.outputs?.find(r => r.output === output);
    if (!rule || rule[key] === value)
      return;
    rule[key] = value;
    draft.changed();
  }

  function move(output, x, y) {
    const rule = draft.local?.profiles?.[selectedProfile]?.outputs?.find(r => r.output === output);
    if (!rule || (rule.x === x && rule.y === y))
      return;
    rule.x = Math.round(x);
    rule.y = Math.round(y);
    draft.changed();
  }

  // A new profile from how the monitors are now
  function newProfile() {
    draft.local.profiles.push({
      "name": _uniqueName(I18n.tr("Layout {0}", profiles.length + 1)),
      "outputs": outputs.map(monitor => MonitorLayout.ruleFromMonitor(monitor, outputs))
    });
    selectedProfile = draft.local.profiles.length - 1;
    draft.changed();
  }

  function renameProfile(index, name) {
    const target = draft.local?.profiles?.[index];
    if (!target || target.name === name)
      return;
    target.name = name;
    draft.changed();
  }

  function removeProfile(index) {
    if (!draft.local?.profiles?.[index])
      return;
    draft.local.profiles.splice(index, 1);
    selectedProfile = Math.max(0, Math.min(selectedProfile, draft.local.profiles.length - 1));
    draft.changed();
  }

  // Leaves an output out of the profile (one that isn't connected)
  function forgetOutput(output) {
    const list = draft.local?.profiles?.[selectedProfile]?.outputs;
    const index = list ? list.findIndex(rule => rule.output === output) : -1;
    if (index < 0)
      return;
    list.splice(index, 1);
    draft.changed();
  }

  // --- Checks ---

  // Outputs laid out on their own (not disabled, not mirroring)
  readonly property var placedRules: rules.filter(rule => !rule.disabled && !rule.mirror)
  readonly property var placedRects: placedRules.map(rule => rectFor(rule))

  // [{ level: "error" | "warning", text }]: errors block Apply
  readonly property var issues: {
    const result = [];
    const placed = root.placedRules;
    for (const [a, b] of MonitorLayout.overlaps(root.placedRects))
      result.push({
        "level": "error",
        "text": I18n.tr("{0} and {1} overlap", root.labelFor(placed[a]), root.labelFor(placed[b]))
      });
    if (placed.length === 0 && root.rules.length > 0)
      result.push({
        "level": "error",
        "text": I18n.tr("Every monitor is off")
      });
    for (const index of MonitorLayout.islands(root.placedRects))
      result.push({
        "level": "warning",
        "text": I18n.tr("{0} doesn't touch the others, so the cursor can't reach it", root.labelFor(placed[index]))
      });
    for (const rule of root.rules) {
      if (rule.mirror && !root.rules.some(other => other.output === rule.mirror && !other.disabled && !other.mirror))
        result.push({
          "level": "error",
          "text": I18n.tr("{0} mirrors a monitor that isn't shown", root.labelFor(rule))
        });
      const monitor = root.monitorFor(rule);
      const mode = MonitorLayout.parseMode(rule.mode);
      if (monitor && mode && !rule.disabled && MonitorLayout.validScales(mode.width, mode.height).indexOf(rule.scale) < 0)
        result.push({
          "level": "warning",
          "text": I18n.tr("Hyprland rounds {0}'s scale to one that fits its resolution", root.labelFor(rule))
        });
    }
    for (const file of HyprlandConfigManager.monitorConflicts)
      result.push({
        "level": "warning",
        "text": I18n.tr("{0} sets monitors too, and loads after axiom, so its rules win", file)
      });
    return result;
  }
  readonly property bool canApply: !issues.some(issue => issue.level === "error")

  // A rule's name on the page: its connector, else its description
  function labelFor(rule) {
    const monitor = monitorFor(rule);
    return monitor?.name || rule?.label || String(rule?.output ?? "").replace(/^desc:/, "");
  }

  // --- Apply, keep, revert ---

  // Waiting for keep()/revert() after Apply
  property bool pending: false
  property int secondsLeft: 0
  readonly property int confirmSeconds: 15
  property var _revertLua: []

  // Tries the selected profile now; keep() saves it. A profile for other
  // monitors can only be saved.
  function apply() {
    if (!canApply || pending)
      return;
    if (!selectedIsLive) {
      save();
      return;
    }
    const all = outputs;
    const mirrorName = output => MonitorLayout.find(output, all)?.name ?? "";
    _revertLua = HyprLua.monitorCalls(all.map(monitor => MonitorLayout.ruleFromMonitor(monitor, all)), mirrorName);
    HyprlandManager.runLua(HyprLua.monitorCalls(rules.filter(rule => monitorFor(rule) !== null), mirrorName).join("\n"));
    secondsLeft = confirmSeconds;
    pending = true;
    _countdown.restart();
    _refreshSoon.restart();
  }

  function keep() {
    if (!pending)
      return;
    pending = false;
    _countdown.stop();
    if (!draft.save()) {
      console.warn("[MonitorManager] Could not save the monitor layout; putting the old one back");
      _runRevert();
    }
  }

  function revert() {
    if (!pending)
      return;
    pending = false;
    _countdown.stop();
    _runRevert();
  }

  function _runRevert() {
    HyprlandManager.runLua(_revertLua.join("\n"));
    _refreshSoon.restart();
  }

  property Timer _countdown: Timer {
    interval: 1000
    repeat: true
    onTriggered: {
      root.secondsLeft--;
      if (root.secondsLeft <= 0)
        root.revert();
    }
  }

  // --- Identify ---

  // Each screen shows its name for a moment
  property bool identifying: false

  function identify() {
    identifying = true;
    _identifyTimer.restart();
  }

  property Timer _identifyTimer: Timer {
    interval: 3000
    onTriggered: root.identifying = false
  }

  // --- Primary ---

  function setPrimary(name) {
    SettingsManager.commitValue("General.primaryMonitor", name);
  }

  // --- Reading the monitors ---

  function refresh() {
    if (!_read.running)
      _read.running = true;
  }

  property Process _read: Process {
    command: ["hyprctl", "monitors", "all", "-j"]
    stdout: StdioCollector {
      onStreamFinished: {
        try {
          root.outputs = JSON.parse(text);
        } catch (e) {
          console.warn("[MonitorManager] Could not parse hyprctl monitors:", e);
        }
      }
    }
  }

  // Mode changes send no event: read again once they've settled
  property Timer _refreshSoon: Timer {
    interval: 600
    onTriggered: root.refresh()
  }

  property Connections _events: Connections {
    target: Hyprland

    function onRawEvent(event) {
      if (!["monitoradded", "monitoraddedv2", "monitorremoved", "monitorremovedv2", "configreloaded"].includes(event.name))
        return;
      if (root.pageShown && !root.pending && !draft.isDirty && event.name !== "configreloaded") {
        draft.load();
        root._detectPending = true;
      }
      root._refreshSoon.restart();
    }
  }

  Component.onCompleted: refresh()

  // Recovers from a layout that can't be seen: `qs -c axiom ipc call
  // monitors revert`
  property IpcHandler _ipc: IpcHandler {
    target: "monitors"

    function open(): void {
      ShellManager.openOverlayPage("Monitors");
    }

    function keep(): void {
      root.keep();
    }

    function revert(): void {
      root.revert();
    }

    function identify(): void {
      root.identify();
    }
  }
}
