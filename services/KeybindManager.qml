pragma Singleton
import QtQuick

import qs.config
import qs.components.methods

/*
 * KeybindManager reads the keybinds the compositor has registered
 * (CompositorManager.withBinds). Each bind's `description` is its label (on
 * Hyprland's Lua config every action is an opaque `__lua` dispatcher). A
 * "Section: Label" prefix picks the overlay section.
 *
 * Also the Keybinds page's editor for axiom's own binds (Keybinds.binds): a
 * draft saved with save(), per-bind issues, presets, and recording a key
 * combo (CompositorManager.captureKeys meanwhile, so the compositor's binds
 * don't swallow the keys being recorded).
 */
QtObject {
  id: root

  // [{ title, undescribed, binds: [{ label, combos: [{ mods: ["SUPER", "SHIFT"], keys: ["H", "←"] }], axiom, user }] }]
  // `title` is "" for binds with no section (shown as "Other"); `undescribed`
  // marks the section of binds without a description (label ""). A row's
  // `axiom` / `user` say whether any of its binds are axiom's own (applied
  // from Keybinds.binds) / from the user's compositor config.
  readonly property var keybindings: root._buildKeybindings(root._entries, root._axiomIds)
  // How many binds the compositor reported
  property int count: 0
  // The Keybinds page's search and filter chips (KeybindFilter), here so
  // they survive the page reloading: section keys (KeybindFilter.sectionKey),
  // modifier names, sources ("axiom" | "user")
  property string query: ""
  property var sectionFilter: []
  property var modFilter: []
  property var sourceFilter: []
  readonly property bool filtering: sectionFilter.length > 0 || modFilter.length > 0 || sourceFilter.length > 0

  // The chips: [{ key, title, undescribed, count }] per section, and the
  // modifiers the binds use, in _modifiers order
  readonly property var sectionOptions: root.keybindings.filter(section => section.binds.length > 0).map(section => ({
        "key": KeybindFilter.sectionKey(section),
        "title": section.title,
        "undescribed": section.undescribed,
        "count": section.binds.length
      }))
  readonly property var modOptions: {
    const used = {};
    for (const section of root.keybindings)
      for (const row of section.binds)
        for (const combo of row.combos)
          for (const mod of combo.mods)
            used[mod] = true;
    return root._modifiers.map(m => m.name).filter(name => used[name]);
  }

  // group: "section" | "mod" | "source", or the editor's "editSection" |
  // "editMod"
  function toggleFilter(group, value) {
    const name = group + "Filter";
    const current = root[name];
    root[name] = current.includes(value) ? current.filter(v => v !== value) : current.concat([value]);
  }

  function clearFilters() {
    root.sectionFilter = [];
    root.modFilter = [];
    root.sourceFilter = [];
  }

  function clearEditFilters() {
    root.editSectionFilter = [];
    root.editModFilter = [];
    root.editIssuesOnly = false;
  }
  // The Keybinds page shows the editor instead of the list
  property bool editing: false

  // --- The editor ---

  // The editor's search and sort ("manual" | "key" | "action" | "section"),
  // here so they survive the page reloading. They only change what's shown:
  // the saved order stays as it is.
  property string editQuery: ""
  property string editSort: "manual"
  // The editor's chips: sections, modifier names, and only binds with issues
  property var editSectionFilter: []
  property var editModFilter: []
  property bool editIssuesOnly: false
  readonly property bool editFiltering: editSectionFilter.length > 0 || editModFilter.length > 0 || editIssuesOnly
  readonly property bool reorderable: editSort === "manual" && editQuery.trim() === "" && !editFiltering

  property ConfigDraft _draft: ConfigDraft {
    id: draft
    path: ["Keybinds", "binds"]
  }
  // [{ key, action, argument, description }]
  readonly property var binds: draft.local ?? []
  readonly property alias isDirty: draft.isDirty

  readonly property var _actionSchema: ConfigManager.configSchema?.properties?.Keybinds?.properties?.binds?.items?.properties?.action ?? ({})
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
  // I18n.tr("Workspace") I18n.tr("Special") I18n.tr("Custom")
  readonly property var actionSections: ["Axiom", "Apps", "Media", "Window", "Workspace", "Special", "Custom"]

  // Material Symbols per action (the picker and its button)
  readonly property var _actionIcons: ({
      "launcher": "apps",
      "launcherSearch": "search",
      "overlay": "dashboard",
      "overlayPage": "web_stories",
      "edgeMenu": "side_navigation",
      "dock": "dock_to_bottom",
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
      "pseudo": "picture_in_picture_alt",
      "toggleSplit": "splitscreen_right",
      "stripSwapColumn": "swap_horiz",
      "stripWider": "width_wide",
      "stripNarrower": "width_normal",
      "stripFit": "fit_screen",
      "windowSwitcher": "tab",
      "windowSwitcherReverse": "tab",
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
      "screenRecord": "videocam",
      "exitSession": "logout",
      "exec": "code",
      "raw": "data_object"
    })

  // [{ action, label, section, icon }], one per action, in schema order
  // The actions the running compositor can do (BindActions.needs); a saved
  // bind with another keeps it, flagged in `issues`
  readonly property var actionInfo: root.actions.filter(action => BindActions.supported(action, CompositorManager.supports)).map(action => ({
        "action": action,
        "label": root.actionLabels[action] ?? action,
        "section": action === "exec" ? "Apps" : BindActions.sectionFor(action),
        "icon": root._actionIcons[action] ?? "keyboard"
      }))

  function actionIcon(action) {
    return root._actionIcons[action] ?? "keyboard";
  }

  // The argument an action starts with when picked (else empty)
  readonly property var _argumentDefaults: BindActions.argumentDefaults

  // What an action's free-text argument is, for its placeholder
  function argumentKind(action) {
    return BindActions.argumentKind(action);
  }

  function needsArgument(action) {
    return BindActions.needsArgument(action);
  }

  // The choices for an action's argument, or null for free text
  function argumentOptions(action) {
    switch (BindActions.argumentKind(action)) {
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
    case "dock":
      return DockConfig.docks.map(dock => dock.id);
    case "view":
      return OverlayConfig.views.filter(view => view.visible !== false).map(view => view.name || view.type).concat(["Layouts"]).filter((name, i, all) => all.indexOf(name) === i);
    }
    return null;
  }

  // The choices for an action's call, or null when it has none
  function callOptions(action) {
    return BindActions.hasCalls(action) ? ["toggle", "open", "close"] : null;
  }

  // A call's label for an action (a caffeine or night light bind turns it
  // on or off, a recording bind starts or stops it)
  function callLabels(action) {
    const onOff = action === "idleInhibit" || action === "nightLight";
    const record = action === "screenRecord";
    return {
      "toggle": I18n.tr("Toggle"),
      "open": record ? I18n.tr("Start") : onOff ? I18n.tr("Turn on") : I18n.tr("Open"),
      "close": record ? I18n.tr("Stop") : onOff ? I18n.tr("Turn off") : I18n.tr("Close")
    };
  }

  // In the sorted views, whether binds with no key go first (after the top
  // Add button) rather than last (after the bottom one)
  property bool keylessFirst: false

  // An editor bind's section on the Keybinds page: its description's
  // "Section:" prefix, else its action's
  function _bindSection(bind) {
    return BindActions.hasOwnSection(bind.description) ? String(bind.description).split(":")[0] : BindActions.sectionFor(bind.action);
  }

  // An editor bind's modifiers, by the names the compositor's binds decode to
  function _bindMods(bind) {
    const id = BindKeys.keyId(bind.key);
    return id === "" ? [] : root._decodeMods(parseInt(id));
  }

  // The editor's chips: [{ key, title, count }] per section (actionSections
  // order, then any others), and the modifiers its binds use
  readonly property var editSectionOptions: {
    const counts = {};
    for (const bind of root.binds) {
      const section = root._bindSection(bind);
      counts[section] = (counts[section] ?? 0) + 1;
    }
    const others = Object.keys(counts).filter(section => !root.actionSections.includes(section)).sort();
    return root.actionSections.filter(section => counts[section]).concat(others).map(section => ({
          "key": section,
          "title": section,
          "count": counts[section]
        }));
  }
  readonly property var editModOptions: {
    const used = {};
    for (const bind of root.binds)
      for (const mod of root._bindMods(bind))
        used[mod] = true;
    return root._modifiers.map(m => m.name).filter(name => used[name]);
  }

  // The shown binds' indices, filtered by editQuery and the chips and
  // sorted by editSort, joined: a string only notifies when it changes, so
  // the rows survive edits that leave the order alone
  readonly property string visibleKey: {
    const query = root.editQuery.trim().toLowerCase();
    const sections = root.editSectionFilter;
    const mods = root.editModFilter;
    const issuesOnly = root.editIssuesOnly;
    const rows = root.binds.map((bind, index) => {
      const key = String(bind.key ?? "").trim();
      const label = root.actionLabels[bind.action] ?? String(bind.action ?? "");
      const section = root._bindSection(bind);
      return {
        "index": index,
        "key": key.split("+").map(part => root.displayKey(part.trim())).join(" + "),
        "label": label,
        "section": section,
        "mods": root._bindMods(bind),
        "text": [key, label, section, bind.argument ?? "", bind.description ?? "", BindActions.defaultLabel(bind)].join("\n").toLowerCase()
      };
    }).filter(row => (query === "" || row.text.includes(query)) && (sections.length === 0 || sections.includes(row.section)) && mods.every(mod => row.mods.includes(mod)) && (!issuesOnly || (root.issues[row.index] ?? []).length > 0));
    const compare = (a, b) => a.toLowerCase().localeCompare(b.toLowerCase());
    // Binds with no key yet go next to the Add button last used
    const keyless = row => Number(row.key === "") * (root.keylessFirst ? -1 : 1);
    const byKey = (a, b) => keyless(a) - keyless(b) || compare(a.key, b.key);
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
    CompositorConfigManager.previewMerge();
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
    const flags = BindActions.actionFlags[action] ?? [];
    const full = {
      "key": "",
      "action": action,
      "argument": "",
      "call": "toggle",
      "description": ""
    };
    for (const flag of BindActions.flagNames)
      full[flag] = flags.includes(flag);
    return Object.assign(full, bind ?? {});
  }

  // Adds a bind at the end, or at the start with atTop (the top Add button)
  function addBind(bind, atTop) {
    // So the new row shows
    editQuery = "";
    clearEditFilters();
    keylessFirst = atTop === true;
    if (keylessFirst)
      draft.local.unshift(_completeBind(bind));
    else
      draft.local.push(_completeBind(bind));
    draft.changed();
  }

  // Adds `bind` at the top, then opens the Keybinds page's editor
  // recording its key (the layouts editor's Add a keybind)
  function addAndRecord(bind) {
    ensureLoaded();
    addBind(bind, true);
    root.editing = true;
    ShellManager.openOverlayPage("Keybinds");
    Qt.callLater(() => root.startRecording(0));
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
      // A raw command is written for the compositor running now
      if (value === "raw")
        bind.compositor = CompositorManager.kind || "hyprland";
      const options = argumentOptions(value);
      if (!needsArgument(value) || (options && !options.includes(bind.argument)))
        bind.argument = _argumentDefaults[value] ?? "";
      if (!BindActions.hasCalls(value))
        bind.call = "toggle";
      const flags = BindActions.actionFlags[value] ?? [];
      for (const flag of BindActions.flagNames)
        bind[flag] = flags.includes(flag);
    }
    draft.changed();
  }

  // Keys the compositor binds outside axiom, by BindKeys.keyId: every bind
  // it reports, less the saved axiom binds the layer applied
  readonly property var _userKeyCounts: BindKeys.userKeyCounts(root._entries, root._appliedBinds)

  // The saved axiom binds the runtime layer applied (the rest it skipped)
  readonly property var _appliedBinds: {
    const skipped = CompositorConfigManager.skippedKeys.map(key => BindKeys.keyId(key));
    return KeybindsConfig.binds.filter(bind => CompositorConfigManager.isComplete(bind) && !skipped.includes(BindKeys.keyId(bind.key)));
  }

  // Their keys, by BindKeys.keyId: { "64:return": true }
  readonly property var _axiomIds: root._appliedBinds.reduce((ids, bind) => {
    const id = BindKeys.keyId(bind.key);
    if (id !== "")
      ids[id] = true;
    return ids;
  }, {})

  // Per bind: [{ level: "error" | "warning", text }]
  readonly property var issues: {
    const ids = root.binds.map(bind => BindKeys.keyId(bind.key));
    const counts = {};
    for (const id of ids)
      if (id !== "")
        counts[id] = (counts[id] ?? 0) + 1;
    const runtime = CompositorConfigManager.status !== "loaded";
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
      // The switcher picks when its modifier is released
      if (BindActions.switcherSteps[bind.action] !== undefined && key !== "" && BindActions.switcherHeld(KeyNames.split(key).mods).length === 0)
        found.push({
          "level": "warning",
          "text": I18n.tr("Needs a modifier to hold, like ALT + Tab")
        });
      if (!BindActions.appliesUnder(bind, CompositorManager.kind, CompositorManager.supports))
        found.push({
          "level": "warning",
          "text": bind.action === "raw" ? I18n.tr("Written for another compositor, so it does nothing here") : I18n.tr("This compositor can't do this, so it isn't bound")
        });
      if (ids[i] !== "" && counts[ids[i]] > 1)
        found.push({
          "level": "error",
          "text": I18n.tr("Bound more than once here")
        });
      if (ids[i] !== "" && root._userKeyCounts[ids[i]] > 0)
        found.push({
          "level": "warning",
          "text": runtime ? I18n.tr("Your compositor config uses this key, so it's skipped") : I18n.tr("Your compositor config binds this key too")
        });
      return found;
    });
  }

  readonly property int issueCount: issues.filter(found => found.length > 0).length

  // The binds on keys the user's compositor config binds too
  readonly property var userConflicts: root.binds.map((bind, index) => {
    const id = BindKeys.keyId(bind.key);
    return id !== "" && root._userKeyCounts[id] > 0 ? index : -1;
  }).filter(index => index >= 0)

  // Removes every bind on a key the user's compositor config binds too (until
  // Save, like any edit). Returns how many.
  function removeUserConflicts() {
    const indices = root.userConflicts;
    if (indices.length === 0)
      return 0;
    stopRecording();
    for (let i = indices.length - 1; i >= 0; i--)
      draft.local.splice(indices[i], 1);
    draft.changed();
    return indices.length;
  }

  // Managed mode moves the user's binds into axiom instead of dropping
  // axiom's (CompositorConfigManager.mergeUserBinds)
  readonly property bool canMerge: CompositorConfigManager.mode === "managed"
  // How many binds in user/ a Merge would move (0 until looked at,
  // when the page opens): not every bind there can (a Lua function, a
  // shared module's, one in a submap), so it's not the conflict count
  readonly property int mergeableCount: Math.max(0, CompositorConfigManager.mergeable)

  function mergeUserBinds() {
    stopRecording();
    CompositorConfigManager.mergeUserBinds();
  }

  // Moved binds are saved at once: a draft with unsaved edits takes them
  // too (so its Save keeps them), else it starts over from the config
  property Connections _mergeWatch: Connections {
    target: CompositorConfigManager

    function onBindsMerged(binds) {
      if (!draft.isDirty) {
        draft.load();
        return;
      }
      const complete = binds.map(bind => root._completeBind(bind));
      draft.local = BindKeys.mergeBinds(draft.local, complete);
      draft.saved = BindKeys.mergeBinds(draft.saved, complete);
      draft.changed();
    }

    function onLastMergeChanged() {
      root.refreshSoon();
    }
  }

  // --- Presets ---

  // Presets leave descriptions empty: each bind gets its action's label
  // and section (BindActions.descriptionFor)
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
    if (WorkspacesConfig.hasStrips)
      list.push({
        "id": "strips",
        "title": I18n.tr("Strips"),
        "description": I18n.tr("SUPER + [ or ] swaps the column with the one before or after, SUPER + = or - steps its width, SUPER + CTRL + F fits the visible columns, SUPER + scroll moves focus along it"),
        "binds": [root._workspaceBind("SUPER + bracketleft", "stripSwapColumn", "left"), root._workspaceBind("SUPER + bracketright", "stripSwapColumn", "right"), root._workspaceBind("SUPER + equal", "stripWider", ""), root._workspaceBind("SUPER + minus", "stripNarrower", ""), root._workspaceBind("SUPER + CTRL + F", "stripFit", ""), root._workspaceBind("SUPER + mouse_down", "focusDir", "right"), root._workspaceBind("SUPER + mouse_up", "focusDir", "left")]
      });
    list.push({
      "id": "switcher",
      "title": I18n.tr("Window switcher"),
      "description": I18n.tr("ALT + Tab steps through your windows, most recently used first, with SHIFT backwards; releasing ALT picks"),
      "binds": [root._workspaceBind("ALT + Tab", "windowSwitcher", ""), root._workspaceBind("ALT + SHIFT + Tab", "windowSwitcherReverse", "")]
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
    const used = draft.local.map(bind => BindKeys.keyId(bind.key));
    let added = 0;
    for (const bind of preset.binds) {
      const id = BindKeys.keyId(bind.key);
      if (used.includes(id))
        continue;
      used.push(id);
      draft.local.push(_completeBind(Utils.clone(bind)));
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

  // Meanwhile every key reaches the recorder instead of a bind
  // (CompositorManager.captureKeys)
  function startRecording(index) {
    if (root.recordingIndex === index)
      return;
    if (root.recordingIndex < 0)
      CompositorManager.captureKeys(true);
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
    CompositorManager.captureKeys(false);
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
      "mouse_left": "Scroll ←",
      "mouse_right": "Scroll →",
      "left": "←",
      "right": "→",
      "up": "↑",
      "down": "↓"
    })

  // Every bind the compositor reported (CompositorManager.withBinds)
  property var _entries: []

  function refresh() {
    if (!CompositorManager.supports.bindMerge)
      return;
    if (_reading) {
      _readAgain = true;
      return;
    }
    _reading = true;
    CompositorManager.withBinds(binds => {
      root._reading = false;
      if (binds) {
        root._entries = binds;
        root.count = binds.length;
      }
      if (root._readAgain) {
        root._readAgain = false;
        root.refresh();
      }
    });
  }

  property bool _reading: false
  property bool _readAgain: false

  // After binds were applied at runtime, which no compositor announces
  function refreshSoon() {
    _refreshDelay.restart();
  }

  property Timer _refreshDelay: Timer {
    interval: 500
    onTriggered: root.refresh()
  }

  function _buildKeybindings(entries, axiomIds) {
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
      // Axiom's runtime binds are never in a submap
      const isAxiom = !entry.submap && !!axiomIds[BindKeys.entryId(entry)];

      // Undescribed binds each get their own row, since they share an empty label.
      // Alternatives with the same modifiers share a combo: Super + H / ←.
      const row = label ? rowByKey[rowKey] : undefined;
      if (row) {
        row.axiom = row.axiom || isAxiom;
        row.user = row.user || !isAxiom;
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
        ],
        axiom: isAxiom,
        user: !isAxiom
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
        ],
        axiom: run.rows.some(r => r.axiom),
        user: run.rows.some(r => r.user)
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
      return Utils.spaceWords(key.slice(4));
    if (key.length === 1)
      return key.toUpperCase();
    return key.charAt(0).toUpperCase() + key.slice(1);
  }

  property Connections _compositorEvents: Connections {
    target: CompositorManager

    function onConfigReloaded() {
      root.refresh();
    }
  }

  Component.onCompleted: refresh()
}
