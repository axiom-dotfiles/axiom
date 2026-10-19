# Keybinds (actions and the Keybinds page)

> **Files:** `services/KeybindManager.qml`, `config/KeybindsConfig.qml`, `components/methods/BindActions.qml` (what each action is, its argument kinds), `components/methods/HyprConfigLua.qml` (`bindLua`, `dispatcherLua`), `services/CompositorConfigManager.qml`, `services/HyprlandConfigWriter.qml`, `components/views/Keybinds.qml`, `components/views/keybinds/` (`BindEditor`, `BindSection`, `BindListRow`, `BindInspector`, `KeyMapPanel`, `PresetSheet`, `KeyRecorder`, `FilterChips`), `components/methods/KeyNames.qml`, `components/methods/KeybindFilter.qml`, `components/methods/BindKeys.qml`, `components/methods/BindGroups.qml`, `components/methods/KeyMap.qml`
> **Config:** `Keybinds.binds`, `Apps.terminal`/`fileManager`/`browser`
> **Related:** [Bind merge](bind-merge.md), [Config modes](config-modes.md), [Window switcher](window-switcher.md), [Screenshots and recording](../features/screenshots-recording.md), [Workspace strips](workspace-strips.md)

What a bind can do, and how the Keybinds page lists the compositor's binds and edits axiom's own. The binds are compositor-neutral (`Keybinds.binds`, `Hyprland.binds` before config version 60); each backend's config writer turns them into its own binds (on Hyprland, `HyprConfigLua.bindLua`).

### Bind actions
- `binds` are edited on the Keybinds page, not in settings.
- An action is one of:
  - **An axiom IPC call** (`BindActions.ipcActions`). This includes the `audio`/`media` targets on AudioManager/MediaManager, so the OSD shows.
  - **A compositor action bound directly** (`BindActions.compositorActions`; on Hyprland its Lua in `HyprConfigLua.dispatcherLua`):
    - focus/move/resize, close, fullscreen, floating, pin, special workspaces
    - mouse drag/resize on a `mouse:272` key (Hyprland makes that a mouse bind by itself)
    - the window switcher's `windowSwitcher`/`windowSwitcherReverse`, Lua functions that enter its submap ([Window switcher](window-switcher.md))
    - `exitSession`
    - `pseudo` and `toggleSplit`
    - `raw`: a command in the compositor's own language, for the compositor its `compositor` field names (bound nowhere else). On Hyprland, any dispatcher as Lua, compiled with `load` when the bind is made, so a mistake leaves only that bind a `no_op`
    - `terminal`/`fileManager`/`browser`: exec `Apps.terminalCommand` etc., so the binds follow the `Apps` section's `terminal`/`fileManager`/`browser` (empty is the system default)
    - `mediaStop` etc. on `media`.
  - **`scrollStep`** (`workspaces scroll`, the default SUPER + scroll): along the focused output's strip where it has one (`CompositorManager.stepStrip`, focus follows), else a workspace step that way (`stepWorkspace`).
  - **`screenshot`** (argument `region`/`window`/`screen`) and **`screenRecord`**, which go to ScreenshotManager ([Screenshots and recording](../features/screenshots-recording.md)).
- Binds carry `repeating`/`locked`/`release` flags, preset from `BindActions.actionFlags` when the action is picked.
- **Paused binds** (`paused`) stay in `Keybinds.binds` but aren't bound: every writer and runtime layer reads `KeybindsConfig.activeBinds`, which leaves them out (so does the window switcher's held modifiers). In the editor a paused bind holds no key: it clashes with nothing, isn't a user conflict, and its only issue is an `info` note. `setPaused(indices, on)` pauses one bind, a run or a whole section.
- **A modifier on its own** (a tap): the key is the modifier's keysym alone, `Super_L` (`KeyNames.tapModifier`; `SUPER + Super_L` reads the same). It fires when the key is let go with no other key between, `release` or not, and needs `modifierTap` (`BindActions.keySupported`; niri can't, so it gets a warning and isn't written). Hyprland binds it as `SUPER + Super_L` on release (`HyprConfigLua.bindKey`), sway as `bindsym --release Super_L`. `BindKeys.keyId` leaves a tap's own modifier out of its id, as Hyprland lists the modifier held and sway doesn't.
- **What a compositor can do**: `BindActions.needs` lists the capabilities an action needs (any one of them), e.g. `strip*` → `strips`, `toggleSpecial` → `namedSpecial` or `scratchpad`. The picker (`KeybindManager.actionInfo`) offers only the actions the running compositor supports; a saved bind with another keeps it and gets a warning in `issues` (`BindActions.appliesUnder`), as does a `raw` bind written for another compositor. An action the compositor does itself and can't be bound to (`CompositorManager.builtInBinds`: niri's Mod + left/right drag) gets an `info` note instead when the bind is on that combo, or a warning naming the combo when it isn't; `info` notes don't count as issues (`hasIssue`, `issueCount`). Binds the layout leaves idle get an `info` note too: `strip*` with no strip anywhere (the strip binds are in the defaults for every layout), and on Hyprland `toggleSplit` (dwindle's) on the scrolling layout.

### What the page lists
- Every bind the compositor reports (`CompositorManager.withBinds`, needs `bindMerge`), grouped by "Section: Label" descriptions.
- Axiom's own `Keybinds.binds` are edited in a `ConfigDraft` and saved with `save()`.
- Per-bind `issues`:
  - no key, a bad modifier, a missing argument, a duplicate
  - a key the user's own config binds. This is Hyprland's binds minus the saved axiom binds it applied, since every Lua bind shows up as an opaque `__lua` dispatcher.
- Each row carries `axiom`/`user`:
  - `axiom`: any of its binds is one of axiom's applied binds (`_axiomIds`, by `BindKeys.keyId`, never in a submap)
  - `user`: it is the user's own.
### The editor
- `Keybinds.qml` while `editing`: the list card (three quarters of `editorWidth`, less where the screen is too narrow for both) beside an inspector card (`sideWidth * 1.45`) that holds Save/Discard.
- **The list** (`BindEditor`): `editLayout`, from `BindGroups.groups` over `visibleIndices` (the search and chips, in the saved order), through a JSON string so it only rebuilds when its shape changes. Sections in `actionSections` order (`BindSection`, folds kept in `EditsManager.keybindsFolded`); in a section, numbered runs (`BindGroups.runKey`: a workspace-number action on its own number key, no label of its own, same modifiers and flags) fold into one row that unfolds (`expandedRuns`). Rows (`BindListRow`): the pause switch, keycaps, the label, flags that are on, an issue mark, the unsaved dot.
- **Selection**: `selectedIndex` / `selectBind(i)`; adds, removes and moves keep it on its bind. `revealRequested(index)` unfolds its section and run and scrolls to it. Add bind and Duplicate select the new bind and start recording its key.
- **The inspector** (`BindInspector`): rebuilt per selection (a Repeater over `[selectedIndex]`), so a typed field never commits onto another bind. With nothing selected, `KeyMapPanel`: `KeyMap.rows`/`extras` coloured by `KeyMap.occupancy` (axiom, paused, the user's config, both) under `keyMapMods`; a free key adds a bind on it, an axiom key selects its bind.
- **Changed and undo**: `_origins` holds each draft bind's index in the saved list (-1 new), matched by JSON whenever `draft.saved` changes and kept by every add/remove/move; `changedBinds` drives the unsaved dots, `revertBind` puts one back. `_remember(text)` snapshots the draft before a removal, preset or multi-bind pause; `undo()` restores it, `undoText` labels the strip. Saving or discarding clears it.
- **Reordering**: while `reorderable` (no search or chips), a row drags within its section over a `DragLayer` in `BindEditor`; the section is the target and `dropAt` turns a row position into `moveBind`.

### Presets
- `presets` are built from the workspace layout: four-way steps in a grid and with dynamic workspaces (up and down the output's list, left and right to the next output), and number keys 1–10 there, as the compositor's list has no set size. With those four-way steps, Southpaw too (SUPER + W/S and H/L through the workspaces, H/L being the next monitor with dynamic workspaces; A/D and J/K move focus; with SHIFT the window goes along). With strips (the scrolling layout's too), the Strips preset. Window management and Strips include SUPER + scroll (`scrollStep`). `presetPlan(id)` says per bind whether it's new, the same as a bind already there, or on a taken key (`takenBy`); the Presets sheet (`PresetSheet`) shows that with checkboxes, taken keys ticked only for a preset that `replaces` (Southpaw, whose keys the defaults bind to other actions). `applyPreset(id, keyIds)` adds the ticked new binds and puts the ticked taken ones in place of the binds on their keys. All of it is an unsaved draft edit until Save, and Undo takes it back.

### Recording a key
- `startRecording(index)` calls `CompositorManager.captureKeys(true)` (needs `keyCapture`), so bound combos reach `keybinds/KeyRecorder` instead of firing.
  - The recorder's window also inhibits the compositor's shortcuts while it records (a `ShortcutInhibitor`): niri's only way, as it has no empty mode to enter.
  - On Hyprland (`HyprlandManager.captureKeys`) that is an empty `axiom_record` submap. Hyprland only registers a submap that has a bind, so the submap has one unreachable bind.
  - A Lua timer leaves the submap after 30 s, even if qs dies.
  - This is the key recorder. It is unrelated to screen recording.
- A modifier pressed alone and let go records a tap (`KeyNames.tapName`, left or right from the keycode) and sets `release`, where the compositor has `modifierTap`.
- `components/methods/KeyNames` turns the Qt key event into a Hyprland key name.
- A wheel turn over the recorder becomes `mouse_up`/`mouse_down`/`mouse_left`/`mouse_right` with the modifiers held (`fromWheel`).
- Known gap: the recorder doesn't tell keypad keys apart, and doesn't map AltGr.

### Filters
- **List tab.**
  - A search plus toggle chips: `query`, `sectionFilter`, `modFilter`, `sourceFilter`. They live in the manager so they survive the page.
  - Changed with `toggleFilter(group, value)` and `clearFilters()`.
  - The chips come from `sectionOptions`/`modOptions`, built from the binds, not from the filtered result.
  - Filtering is done by `components/methods/KeybindFilter`. Chips in one group are alternatives; the groups and the search all apply.
- **Editor tab.**
  - Its own chips: `editSectionFilter`, `editModFilter`, `editIssuesOnly`, with options `editSectionOptions`/`editModOptions`.
  - Cleared by `clearEditFilters()`, which Add bind also calls.
  - Applied in `visibleKey`. Turning any of them on, or searching, turns `reorderable` off.
- Both tabs draw their chips with `views/keybinds/FilterChips`: groups of `{ value, label }` options, a `selection` map, and `toggled`/`cleared` signals.
