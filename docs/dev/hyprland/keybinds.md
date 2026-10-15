# Keybinds (actions and the Keybinds page)

> **Files:** `services/KeybindManager.qml`, `components/methods/BindActions.qml` (what each action is, its argument kinds), `components/methods/HyprConfigLua.qml` (`bindLua`, `dispatcherLua`), `services/HyprlandConfigManager.qml`, `components/views/Keybinds.qml`, `components/views/keybinds/KeyRecorder.qml`, `components/views/keybinds/FilterChips.qml`, `components/methods/KeyNames.qml`, `components/methods/KeybindFilter.qml`, `components/methods/HyprBinds.qml`
> **Config:** `Hyprland.binds`, `Apps.terminal`/`fileManager`/`browser`
> **Related:** [Bind merge](bind-merge.md), [Config modes](config-modes.md), [Window switcher](window-switcher.md), [Screenshots and recording](../features/screenshots-recording.md), [Workspace strips](workspace-strips.md)

What a bind can do, and how the Keybinds page lists Hyprland's binds and edits axiom's own.

### Bind actions
- `binds` are edited on the Keybinds page, not in settings.
- An action is one of:
  - **An axiom IPC call** (`BindActions.ipcActions`). This includes the `audio`/`media` targets on AudioManager/MediaManager, so the OSD shows.
  - **A Hyprland dispatcher bound directly** (`BindActions.compositorActions`, its Lua in `HyprConfigLua.dispatcherLua`):
    - focus/move/resize, close, fullscreen, floating, pin, special workspaces
    - mouse drag/resize on a `mouse:272` key (Hyprland makes that a mouse bind by itself)
    - the window switcher's `windowSwitcher`/`windowSwitcherReverse`, Lua functions that enter its submap ([Window switcher](window-switcher.md))
    - `exitHyprland`
    - `pseudo` and `toggleSplit`
    - `lua`: any dispatcher as Lua, compiled with `load` when the bind is made, so a mistake leaves only that bind a `no_op`
    - `terminal`/`fileManager`/`browser`: exec `Apps.terminalCommand` etc., so the binds follow the `Apps` section's `terminal`/`fileManager`/`browser` (empty is the system default)
    - `mediaStop` etc. on `media`.
  - **`screenshot`** (argument `region`/`window`/`screen`) and **`screenRecord`**, which go to ScreenshotManager ([Screenshots and recording](../features/screenshots-recording.md)).
- Binds carry `repeating`/`locked`/`release` flags, preset from `BindActions.actionFlags` when the action is picked.

### What the page lists
- Every bind Hyprland reports (`HyprlandManager.withBinds`), grouped by "Section: Label" descriptions.
- Axiom's own `Hyprland.binds` are edited in a `ConfigDraft` and saved with `save()`.
- Per-bind `issues`:
  - no key, a bad modifier, a missing argument, a duplicate
  - a key the user's own config binds. This is Hyprland's binds minus the saved axiom binds it applied, since every Lua bind shows up as an opaque `__lua` dispatcher.
- Each row carries `axiom`/`user`:
  - `axiom`: any of its binds is one of axiom's applied binds (`_axiomIds`, by `HyprBinds.keyId`, never in a submap)
  - `user`: it is the user's own.
- `presets` are built from the workspace layout. `applyPreset` skips keys already in use.

### Recording a key
- `startRecording(index)` puts Hyprland in an empty `axiom_record` submap, so bound combos reach `keybinds/KeyRecorder`.
  - Hyprland only registers a submap that has a bind, so the submap has one unreachable bind.
  - A Lua timer leaves the submap after 30 s, even if qs dies.
  - This is the key recorder. It is unrelated to screen recording.
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
  - Applied in `visibleKey`. Turning any of them on turns `reorderable` off.
- Both tabs draw their chips with `views/keybinds/FilterChips`: groups of `{ value, label }` options, a `selection` map, and `toggled`/`cleared` signals.
