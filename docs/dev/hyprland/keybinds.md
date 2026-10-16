# Keybinds (actions and the Keybinds page)

> **Files:** `services/KeybindManager.qml`, `config/KeybindsConfig.qml`, `components/methods/BindActions.qml` (what each action is, its argument kinds), `components/methods/HyprConfigLua.qml` (`bindLua`, `dispatcherLua`), `services/CompositorConfigManager.qml`, `services/HyprlandConfigWriter.qml`, `components/views/Keybinds.qml`, `components/views/keybinds/KeyRecorder.qml`, `components/views/keybinds/FilterChips.qml`, `components/methods/KeyNames.qml`, `components/methods/KeybindFilter.qml`, `components/methods/BindKeys.qml`
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
  - **`screenshot`** (argument `region`/`window`/`screen`) and **`screenRecord`**, which go to ScreenshotManager ([Screenshots and recording](../features/screenshots-recording.md)).
- Binds carry `repeating`/`locked`/`release` flags, preset from `BindActions.actionFlags` when the action is picked.
- **What a compositor can do**: `BindActions.needs` lists the capabilities an action needs (any one of them), e.g. `strip*` → `strips`, `toggleSpecial` → `namedSpecial` or `scratchpad`. The picker (`KeybindManager.actionInfo`) offers only the actions the running compositor supports; a saved bind with another keeps it and gets a warning in `issues` (`BindActions.appliesUnder`), as does a `raw` bind written for another compositor.

### What the page lists
- Every bind the compositor reports (`CompositorManager.withBinds`, needs `bindMerge`), grouped by "Section: Label" descriptions.
- Axiom's own `Keybinds.binds` are edited in a `ConfigDraft` and saved with `save()`.
- Per-bind `issues`:
  - no key, a bad modifier, a missing argument, a duplicate
  - a key the user's own config binds. This is Hyprland's binds minus the saved axiom binds it applied, since every Lua bind shows up as an opaque `__lua` dispatcher.
- Each row carries `axiom`/`user`:
  - `axiom`: any of its binds is one of axiom's applied binds (`_axiomIds`, by `BindKeys.keyId`, never in a submap)
  - `user`: it is the user's own.
- `presets` are built from the workspace layout. `applyPreset` skips keys already in use.

### Recording a key
- `startRecording(index)` calls `CompositorManager.captureKeys(true)` (needs `keyCapture`), so bound combos reach `keybinds/KeyRecorder`.
  - On Hyprland (`HyprlandManager.captureKeys`) that is an empty `axiom_record` submap. Hyprland only registers a submap that has a bind, so the submap has one unreachable bind.
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
