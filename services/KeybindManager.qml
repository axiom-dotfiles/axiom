pragma Singleton
import QtQuick

import Quickshell.Io
import Quickshell.Hyprland

import qs.config
import qs.components.methods

/*
 * KeybindManager reads the keybinds Hyprland has registered (`hyprctl binds -j`).
 * With the Lua config every action is an opaque `__lua` dispatcher, so each bind's
 * `description` option is the label. A "Section: Label" prefix picks the overlay section.
 *
 * Also the Keybinds page's editor for axiom's own binds (Hyprland.binds): a
 * draft saved with save(), per-bind issues, presets, and recording a key
 * combo (Hyprland is put in an empty submap meanwhile, so its binds don't
 * swallow the keys being recorded).
 */
QtObject {
  id: root

  // [{ title, undescribed, binds: [{ label, combos: [{ mods: ["SUPER", "SHIFT"], keys: ["H", "←"] }] }] }]
  // `title` is "" for binds with no section (shown as "Other"); `undescribed`
  // marks the section of binds without a description (label "").
  property var keybindings: []
  // How many binds Hyprland reported
  property int count: 0
  // The Keybinds page's search, here so it survives the page reloading
  property string query: ""
  // The Keybinds page shows the editor instead of the list
  property bool editing: false

  // --- The editor ---

  // The editor's search and sort ("manual" | "key" | "action" | "section"),
  // here so they survive the page reloading. They only change what's shown:
  // the saved order stays as it is.
  property string editQuery: ""
  property string editSort: "manual"
  readonly property bool reorderable: editSort === "manual" && editQuery.trim() === ""

  property ConfigDraft _draft: ConfigDraft {
    id: draft
    path: ["Hyprland", "binds"]
  }
  // [{ key, action, argument, description }]
  readonly property var binds: draft.local ?? []
  readonly property alias isDirty: draft.isDirty

  readonly property var _actionSchema: ConfigManager.configSchema?.properties?.Hyprland?.properties?.binds?.items?.properties?.action ?? ({})
  readonly property var actions: _actionSchema.enum ?? []
  // Action -> its label (translated; the schema's labels are keys already)
  readonly property var _actionLabelSchema: _actionSchema["x-enumLabels"] ?? ({})
  readonly property var actionLabels: Object.keys(_actionLabelSchema).reduce((labels, action) => {
    const english = _actionLabelSchema[action];
    labels[action] = I18n.tr(english);
    return labels;
  }, {})

  // The action picker's categories, in tab order ("" is All). `exec` is
  // filed under Apps there; everything else by its section on the page.
  // I18n.tr("Axiom") I18n.tr("Apps") I18n.tr("Media") I18n.tr("Window")
  // I18n.tr("Workspace") I18n.tr("Special")
  readonly property var actionSections: ["Axiom", "Apps", "Media", "Window", "Workspace", "Special"]

  // Material Symbols per action (the picker and its button)
  readonly property var _actionIcons: ({
      "launcher": "apps",
      "launcherSearch": "search",
      "overlay": "dashboard",
      "overlayPage": "web_stories",
      "edgeMenu": "side_navigation",
      "workspaceOverview": "grid_view",
      "powerMenu": "power_settings_new",
      "lock": "lock",
      "toggleDnd": "do_not_disturb_on",
      "clearNotifications": "clear_all",
      "idleInhibit": "coffee",
      "nightLight": "nightlight",
      "nextWallpaper": "wallpaper",
      "workspaceStep": "swap_horiz",
      "moveWindowStep": "move_item",
      "moveWindowStepSilent": "send",
      "workspaceNth": "counter_1",
      "moveWindowNth": "move_item",
      "moveWindowNthSilent": "send",
      "focusDir": "center_focus_strong",
      "moveWindowDir": "open_with",
      "resizeWindow": "open_in_full",
      "closeWindow": "close",
      "fullscreen": "fullscreen",
      "toggleFloat": "picture_in_picture",
      "pin": "push_pin",
      "centerWindow": "center_focus_weak",
      "toggleGroup": "tab_group",
      "mouseDrag": "drag_pan",
      "mouseResize": "drag_handle",
      "toggleSpecial": "star",
      "moveToSpecial": "star_half",
      "restartShell": "restart_alt",
      "volumeUp": "volume_up",
      "volumeDown": "volume_down",
      "toggleMute": "volume_off",
      "toggleMicMute": "mic_off",
      "brightnessUp": "brightness_high",
      "brightnessDown": "brightness_low",
      "mediaPlayPause": "play_pause",
      "mediaNext": "skip_next",
      "mediaPrevious": "skip_previous",
      "mediaStop": "stop",
      "terminal": "terminal",
      "fileManager": "folder",
      "browser": "language",
      "screenshot": "screenshot_region",
      "exitHyprland": "logout",
      "exec": "code"
    })

  // [{ action, label, section, icon }], one per action, in schema order
  readonly property var actionInfo: root.actions.map(action => ({
        "action": action,
        "label": root.actionLabels[action] ?? action,
        "section": action === "exec" ? "Apps" : HyprlandConfigManager.sectionFor(action),
        "icon": root._actionIcons[action] ?? "keyboard"
      }))

  function actionIcon(action) {
    return root._actionIcons[action] ?? "keyboard";
  }

  // What an action's argument is; actions without one aren't listed
  readonly property var _argumentKinds: ({
      "launcherSearch": "text",
      "exec": "text",
      "overlayPage": "view",
      "edgeMenu": "edgeMenu",
      "workspaceStep": "direction",
      "moveWindowStep": "direction",
      "moveWindowStepSilent": "direction",
      "workspaceNth": "workspace",
      "moveWindowNth": "workspace",
      "moveWindowNthSilent": "workspace",
      "focusDir": "direction",
      "moveWindowDir": "direction",
      "resizeWindow": "resize",
      "toggleSpecial": "special",
      "moveToSpecial": "special",
      "screenshot": "screenshot"
    })

  // The argument an action starts with when picked (else empty)
  readonly property var _argumentDefaults: ({
      "screenshot": "region"
    })

  // What an action's free-text argument is, for its placeholder
  function argumentKind(action) {
    return _argumentKinds[action] ?? "";
  }

  function needsArgument(action) {
    return _argumentKinds[action] !== undefined;
  }

  // The choices for an action's argument, or null for free text
  function argumentOptions(action) {
    switch (_argumentKinds[action]) {
    case "direction":
      return ["left", "right", "up", "down"];
    case "workspace":
      return Array.from({
        "length": WorkspacesConfig.size
      }, (_, i) => String(i + 1));
    case "screenshot":
      return ["region", "window", "screen"];
    case "edgeMenu":
      return EdgeMenusConfig.menus.map(menu => menu.id).filter(id => id);
    case "view":
      return OverlayConfig.views.filter(view => view.visible !== false).map(view => view.name || view.type).concat(["OverlayEditor"]).filter((name, i, all) => all.indexOf(name) === i);
    }
    return null;
  }

  // The shown binds' indices, filtered by editQuery and sorted by editSort,
  // joined: a string only notifies when it changes, so the rows survive
  // edits that leave the order alone
  readonly property string visibleKey: {
    const query = root.editQuery.trim().toLowerCase();
    const rows = root.binds.map((bind, index) => {
      const key = String(bind.key ?? "").trim();
      const label = root.actionLabels[bind.action] ?? String(bind.action ?? "");
      const section = HyprlandConfigManager.hasOwnSection(bind.description) ? String(bind.description).split(":")[0] : HyprlandConfigManager.sectionFor(bind.action);
      return {
        "index": index,
        "key": key.split("+").map(part => root.displayKey(part.trim())).join(" + "),
        "label": label,
        "section": section,
        "text": [key, label, section, bind.argument ?? "", bind.description ?? "", HyprlandConfigManager.defaultLabel(bind)].join("\n").toLowerCase()
      };
    }).filter(row => query === "" || row.text.includes(query));
    const compare = (a, b) => a.toLowerCase().localeCompare(b.toLowerCase());
    // Binds with no key yet go last, next to the Add button
    const byKey = (a, b) => Number(a.key === "") - Number(b.key === "") || compare(a.key, b.key);
    const sorters = {
      "key": byKey,
      "action": (a, b) => compare(a.label, b.label) || byKey(a, b),
      "section": (a, b) => compare(a.section, b.section) || compare(a.label, b.label) || byKey(a, b)
    };
    const sorter = sorters[root.editSort];
    if (sorter)
      rows.sort((a, b) => sorter(a, b) || a.index - b.index);
    return rows.map(row => row.index).join(",");
  }
  readonly property var visibleIndices: visibleKey === "" ? [] : visibleKey.split(",").map(Number)

  // Loads the draft unless it holds unsaved edits (the page is rebuilt
  // whenever the overlay reopens)
  function ensureLoaded() {
    if (!draft.isDirty)
      draft.load();
    refresh();
  }

  function save() {
    stopRecording();
    draft.save();
  }

  function reset() {
    stopRecording();
    draft.load();
  }

  // A bind with every field, its flags from its action unless given
  function _completeBind(bind) {
    const action = bind?.action ?? "launcher";
    const flags = HyprlandConfigManager.actionFlags[action] ?? [];
    const full = {
      "key": "",
      "action": action,
      "argument": "",
      "description": ""
    };
    for (const flag of HyprlandConfigManager.flagNames)
      full[flag] = flags.includes(flag);
    return Object.assign(full, bind ?? {});
  }

  function addBind(bind) {
    // So the new row shows
    editQuery = "";
    draft.local.push(_completeBind(bind));
    draft.changed();
  }

  function removeBind(index) {
    stopRecording();
    draft.local.splice(index, 1);
    draft.changed();
  }

  function moveBind(from, to) {
    if (to < 0 || to >= draft.local.length)
      return;
    draft.local.splice(to, 0, draft.local.splice(from, 1)[0]);
    draft.changed();
  }

  function setField(index, field, value) {
    const bind = draft.local[index];
    if (!bind || bind[field] === value)
      return;
    bind[field] = value;
    // An argument meant for the old action rarely fits the new one, and
    // the flags follow the new action
    if (field === "action") {
      const options = argumentOptions(value);
      if (!needsArgument(value) || (options && !options.includes(bind.argument)))
        bind.argument = _argumentDefaults[value] ?? "";
      const flags = HyprlandConfigManager.actionFlags[value] ?? [];
      for (const flag of HyprlandConfigManager.flagNames)
        bind[flag] = flags.includes(flag);
    }
    draft.changed();
  }

  // Keys Hyprland binds outside axiom, by HyprBinds.keyId: every bind
  // Hyprland reports, less the saved axiom binds it applied
  readonly property var _userKeyCounts: {
    const skipped = HyprlandConfigManager.skippedKeys.map(key => HyprBinds.keyId(key));
    const applied = HyprlandConfig.binds.filter(bind => HyprlandConfigManager.isComplete(bind) && !skipped.includes(HyprBinds.keyId(bind.key)));
    return HyprBinds.userKeyCounts(root._entries, applied);
  }

  // Per bind: [{ level: "error" | "warning", text }]
  readonly property var issues: {
    const ids = root.binds.map(bind => HyprBinds.keyId(bind.key));
    const counts = {};
    for (const id of ids)
      if (id !== "")
        counts[id] = (counts[id] ?? 0) + 1;
    const runtime = HyprlandConfigManager.status !== "loaded";
    return root.binds.map((bind, i) => {
      const found = [];
      const key = String(bind.key ?? "").trim();
      if (key === "")
        found.push({
          "level": "warning",
          "text": I18n.tr("No key yet, so it isn't bound")
        });
      else if (ids[i] === "")
        found.push({
          "level": "error",
          "text": I18n.tr("Unknown modifier in \"{0}\"", key)
        });
      if (root.needsArgument(bind.action) && String(bind.argument ?? "").trim() === "")
        found.push({
          "level": "warning",
          "text": I18n.tr("Needs an argument, so it isn't bound")
        });
      if (ids[i] !== "" && counts[ids[i]] > 1)
        found.push({
          "level": "error",
          "text": I18n.tr("Bound more than once here")
        });
      if (ids[i] !== "" && root._userKeyCounts[ids[i]] > 0)
        found.push({
          "level": "warning",
          "text": runtime ? I18n.tr("Your Hyprland config uses this key, so it's skipped") : I18n.tr("Your Hyprland config binds this key too")
        });
      return found;
    });
  }

  readonly property int issueCount: issues.filter(found => found.length > 0).length

  // --- Presets ---

  // Presets leave descriptions empty: each bind gets its action's label
  // and section (HyprlandConfigManager.descriptionFor)
  function _workspaceBind(key, action, argument) {
    return {
      "key": key,
      "action": action,
      "argument": argument,
      "description": ""
    };
  }

  // [{ id, title, description, binds }], for the current workspace layout.
  readonly property var presets: {
    const count = Math.min(10, WorkspacesConfig.size);
    const numbers = Array.from({
      "length": count
    }, (_, i) => i + 1);
    const digit = n => n === 10 ? "0" : String(n);
    const list = [
      {
        "id": "essentials",
        "title": I18n.tr("Essentials"),
        "description": I18n.tr("Launcher, overlay, workspace overview, power menu and lock"),
        "binds": [root._workspaceBind("SUPER + space", "launcher", ""), root._workspaceBind("SUPER + Tab", "overlay", ""), root._workspaceBind("SUPER + SHIFT + space", "workspaceOverview", ""), root._workspaceBind("SUPER + Escape", "powerMenu", ""), root._workspaceBind("SUPER + CTRL + L", "lock", "")]
      },
      {
        "id": "numbers",
        "title": I18n.tr("Workspaces 1–{0}", count),
        "description": I18n.tr("SUPER + number goes to a workspace, with SHIFT it takes the window along"),
        "binds": [].concat(...numbers.map(n => [root._workspaceBind("SUPER + " + digit(n), "workspaceNth", String(n)), root._workspaceBind("SUPER + SHIFT + " + digit(n), "moveWindowNth", String(n))]))
      }
    ];
    const directions = WorkspacesConfig.grid ? [["Up", "W", "up"], ["Left", "A", "left"], ["Down", "S", "down"], ["Right", "D", "right"]] : [["Left", "A", "left"], ["Right", "D", "right"]];
    const stepBinds = (mods, keyIndex) => [].concat(...directions.map(d => [root._workspaceBind(mods + d[keyIndex], "workspaceStep", d[2]), root._workspaceBind(mods + "SHIFT + " + d[keyIndex], "moveWindowStep", d[2])]));
    if (WorkspacesConfig.grid)
      list.push({
        "id": "wasd",
        "title": I18n.tr("Grid with WASD"),
        "description": I18n.tr("SUPER + W A S D moves around the grid, with SHIFT it takes the window along"),
        "binds": stepBinds("SUPER + ", 1)
      });
    list.push({
      "id": "arrows",
      "title": WorkspacesConfig.grid ? I18n.tr("Grid with arrows") : I18n.tr("Previous and next"),
      "description": WorkspacesConfig.grid ? I18n.tr("SUPER + CTRL + arrows moves around the grid, with SHIFT it takes the window along") : I18n.tr("SUPER + CTRL + left or right steps through workspaces, with SHIFT it takes the window along"),
      "binds": stepBinds("SUPER + CTRL + ", 0)
    });
    const vim = [["h", "left"], ["j", "down"], ["k", "up"], ["l", "right"]];
    const resize = {
      "h": "-50 0",
      "j": "0 50",
      "k": "0 -50",
      "l": "50 0"
    };
    list.push({
      "id": "windows",
      "title": I18n.tr("Window management"),
      "description": I18n.tr("SUPER + H J K L moves focus, with SHIFT the window, with ALT resizes it; close, fullscreen, floating and mouse drag"),
      "binds": [].concat(...vim.map(d => [root._workspaceBind("SUPER + " + d[0], "focusDir", d[1]), root._workspaceBind("SUPER + SHIFT + " + d[0], "moveWindowDir", d[1]), root._workspaceBind("SUPER + ALT + " + d[0], "resizeWindow", resize[d[0]])])).concat([root._workspaceBind("SUPER + C", "closeWindow", ""), root._workspaceBind("SUPER + F", "fullscreen", ""), root._workspaceBind("SUPER + Z", "toggleFloat", ""), root._workspaceBind("SUPER + mouse:272", "mouseDrag", ""), root._workspaceBind("SUPER + mouse:273", "mouseResize", "")])
    });
    list.push({
      "id": "media",
      "title": I18n.tr("Media keys"),
      "description": I18n.tr("Volume, mute, brightness and playback keys, through axiom so the OSD shows"),
      "binds": [root._workspaceBind("XF86AudioRaiseVolume", "volumeUp", ""), root._workspaceBind("XF86AudioLowerVolume", "volumeDown", ""), root._workspaceBind("XF86AudioMute", "toggleMute", ""), root._workspaceBind("XF86AudioMicMute", "toggleMicMute", ""), root._workspaceBind("XF86MonBrightnessUp", "brightnessUp", ""), root._workspaceBind("XF86MonBrightnessDown", "brightnessDown", ""), root._workspaceBind("XF86AudioPlay", "mediaPlayPause", ""), root._workspaceBind("XF86AudioPause", "mediaPlayPause", ""), root._workspaceBind("XF86AudioNext", "mediaNext", ""), root._workspaceBind("XF86AudioPrev", "mediaPrevious", ""), root._workspaceBind("XF86AudioStop", "mediaStop", "")]
    });
    return list;
  }

  // Adds a preset's binds, skipping keys the list already has. Returns
  // { added, skipped }.
  function applyPreset(id) {
    const preset = root.presets.find(p => p.id === id);
    if (!preset)
      return {
        "added": 0,
        "skipped": 0
      };
    const used = draft.local.map(bind => HyprBinds.keyId(bind.key));
    let added = 0;
    for (const bind of preset.binds) {
      const id = HyprBinds.keyId(bind.key);
      if (used.includes(id))
        continue;
      used.push(id);
      draft.local.push(_completeBind(JSON.parse(JSON.stringify(bind))));
      added++;
    }
    if (added > 0)
      draft.changed();
    return {
      "added": added,
      "skipped": preset.binds.length - added
    };
  }

  // --- Recording a key combo ---

  // The bind whose key is being recorded, or -1
  property int recordingIndex: -1

  // An empty submap (Hyprland only registers one with a bind, hence the
  // unreachable one), so every key reaches the overlay. A Hyprland timer
  // leaves it even if the shell dies meanwhile.
  readonly property string _recordSubmap: "axiom_record"
  readonly property string _leaveRecordLua: `if hl.get_current_submap() == "${_recordSubmap}" then hl.dispatch(hl.dsp.submap("reset")) end`
  readonly property string _enterRecordLua: `hl.define_submap("${_recordSubmap}", function() hl.bind("SUPER + CTRL + ALT + SHIFT + F24", hl.dsp.submap("reset")) end)
hl.timer(function() ${_leaveRecordLua} end, { timeout = 30000, type = "oneshot" })
hl.dispatch(hl.dsp.submap("${_recordSubmap}"))`

  function startRecording(index) {
    if (root.recordingIndex === index)
      return;
    if (root.recordingIndex < 0)
      HyprlandManager.runLua(_enterRecordLua);
    root.recordingIndex = index;
    _recordTimeout.restart();
  }

  function finishRecording(combo) {
    if (root.recordingIndex >= 0)
      setField(root.recordingIndex, "key", combo);
    stopRecording();
  }

  function stopRecording() {
    if (root.recordingIndex < 0)
      return;
    root.recordingIndex = -1;
    _recordTimeout.stop();
    HyprlandManager.runLua(_leaveRecordLua);
  }

  property Timer _recordTimeout: Timer {
    interval: 25000
    onTriggered: root.stopRecording()
  }

  readonly property var _modifiers: [
    {
      name: "SUPER",
      mask: 64
    },
    {
      name: "CTRL",
      mask: 4
    },
    {
      name: "ALT",
      mask: 8
    },
    {
      name: "SHIFT",
      mask: 1
    },
    {
      name: "MOD2",
      mask: 16
    },
    {
      name: "MOD3",
      mask: 32
    },
    {
      name: "MOD5",
      mask: 128
    },
    {
      name: "CAPS",
      mask: 2
    },
  ]

  readonly property var _keyNames: ({
      "mouse:272": "LMB",
      "mouse:273": "RMB",
      "mouse:274": "MMB",
      "mouse_up": "Scroll ↑",
      "mouse_down": "Scroll ↓",
      "left": "←",
      "right": "→",
      "up": "↑",
      "down": "↓"
    })

  // Every bind Hyprland reported, as hyprctl lists them
  property var _entries: []

  function refresh() {
    root._bindsProcess.running = true;
  }

  // After binds were applied at runtime, which Hyprland announces no event for
  function refreshSoon() {
    _refreshDelay.restart();
  }

  property Timer _refreshDelay: Timer {
    interval: 500
    onTriggered: root.refresh()
  }

  function _buildKeybindings(entries) {
    const sections = [];
    const sectionByTitle = {};
    const rowByKey = {};
    let undescribed = null;

    for (const entry of entries) {
      const description = (entry.description || "").trim();
      const split = description.indexOf(": ");
      let title;
      let label;

      if (!description) {
        title = null;
        label = "";
      } else if (split > 0) {
        title = description.slice(0, split).trim();
        label = description.slice(split + 2).trim();
      } else {
        title = entry.submap || "";
        label = description;
      }

      let section = title === null ? undescribed : sectionByTitle[title];
      if (!section) {
        section = {
          title: title ?? "",
          undescribed: title === null,
          binds: []
        };
        if (title === null)
          undescribed = section;
        else {
          sectionByTitle[title] = section;
          sections.push(section);
        }
      }

      const mods = root._decodeMods(entry.modmask);
      const key = root._formatKey(entry.key);
      const rowKey = `${section.title}\u0000${label}`;

      // Undescribed binds each get their own row, since they share an empty label.
      // Alternatives with the same modifiers share a combo: Super + H / ←.
      const row = label ? rowByKey[rowKey] : undefined;
      if (row) {
        const combo = row.combos.find(c => c.mods.join("+") === mods.join("+"));
        if (!combo)
          row.combos.push({
            mods: mods,
            keys: [key]
          });
        else if (!combo.keys.includes(key))
          combo.keys.push(key);
        continue;
      }
      const newRow = {
        label: label,
        combos: [
          {
            mods: mods,
            keys: [key]
          }
        ]
      };
      if (label)
        rowByKey[rowKey] = newRow;
      section.binds.push(newRow);
    }

    if (undescribed)
      sections.push(undescribed);
    for (const section of sections)
      section.binds = root._collapseNumbered(section.binds);
    return sections;
  }

  // Rows like "Go to workspace 1" … "Go to workspace 5", each bound to its
  // own number key with the same modifiers, become one "Go to workspace" row
  // with the key "1–5" (or "1 2 4" when the numbers have gaps).
  function _collapseNumbered(binds) {
    const runs = {};
    for (const row of binds) {
      const match = row.label.match(/^(.*\S)\s+(\d+)$/);
      const combo = row.combos[0];
      // Workspace 10 is usually on the 0 key
      if (!match || row.combos.length !== 1 || combo.keys.length !== 1 || (combo.keys[0] !== match[2] && !(match[2] === "10" && combo.keys[0] === "0")))
        continue;
      const runKey = `${match[1]}\u0000${combo.mods.join("+")}`;
      if (!runs[runKey])
        runs[runKey] = {
          label: match[1],
          mods: combo.mods,
          rows: [],
          numbers: []
        };
      runs[runKey].rows.push(row);
      runs[runKey].numbers.push(parseInt(match[2]));
    }

    const result = [];
    const placed = {};
    for (const row of binds) {
      const runKey = Object.keys(runs).find(k => runs[k].rows.length > 1 && runs[k].rows.includes(row));
      if (runKey === undefined) {
        result.push(row);
        continue;
      }
      if (placed[runKey])
        continue;
      placed[runKey] = true;
      const run = runs[runKey];
      const numbers = run.numbers.slice().sort((a, b) => a - b);
      const contiguous = numbers.every((n, i) => i === 0 || n === numbers[i - 1] + 1);
      result.push({
        label: run.label,
        combos: [
          {
            mods: run.mods,
            keys: contiguous ? [`${numbers[0]}–${numbers[numbers.length - 1]}`] : numbers.map(String)
          }
        ]
      });
    }
    return result;
  }

  function _decodeMods(modmask) {
    return root._modifiers.filter(m => (modmask & m.mask) !== 0).map(m => m.name);
  }

  // A key name as shown on a keycap ("space" -> "Space", "left" -> "←")
  function displayKey(key) {
    return _formatKey(String(key ?? ""));
  }

  function _formatKey(key) {
    if (root._keyNames[key.toLowerCase()] !== undefined)
      return root._keyNames[key.toLowerCase()];
    if (key.startsWith("XF86"))
      return key.slice(4).replace(/([a-z])([A-Z])/g, "$1 $2");
    if (key.length === 1)
      return key.toUpperCase();
    return key.charAt(0).toUpperCase() + key.slice(1);
  }

  property Process _bindsProcess: Process {
    command: ["hyprctl", "binds", "-j"]

    stdout: StdioCollector {
      id: bindsCollector

      onStreamFinished: {
        try {
          const entries = JSON.parse(bindsCollector.text).filter(entry => entry.submap !== root._recordSubmap);
          root._entries = entries;
          root.keybindings = root._buildKeybindings(entries);
          root.count = entries.length;
        } catch (e) {
          console.error("KeybindManager: could not parse hyprctl binds:", e);
        }
      }
    }
  }

  property Connections _hyprlandEvents: Connections {
    target: Hyprland

    function onRawEvent(event) {
      if (event.name === "configreloaded")
        root.refresh();
    }
  }

  Component.onCompleted: refresh()
}
