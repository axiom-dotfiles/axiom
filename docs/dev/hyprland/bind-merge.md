# Merging user binds (managed mode)

> **Files:** `services/HyprlandBindMerge.qml`, `services/HyprlandConfigWriter.qml`, `services/CompositorConfigManager.qml` (`mergeUserBinds`, `previewMerge`), `scripts/merge_hypr_binds.py`, `scripts/hypr_binds.lua`, `components/methods/BindKeys.qml`
> **Config:** `Keybinds.binds`
> **Related:** [Managed takeover](managed-takeover.md), [Keybinds](keybinds.md), [Config modes](config-modes.md)

`mergeUserBinds(only)` moves the binds in `user/*.lua` into `Keybinds.binds`, so axiom owns them and nothing is bound twice. It works in managed mode only.

### Entry points
- The Keybinds page's Merge button.
  - When the page opens, `previewMerge()` counts the binds it would move (`mergeable`).
  - While there are binds to move, the button shows in place of "Remove binds your Hyprland config also has".
- A claim merges only the adopted file's binds, through `mergeUserBinds(name)` (`extract --only`) ([Managed takeover](managed-takeover.md)).

### Extracting (`merge_hypr_binds.py extract`)
- It runs the files through `scripts/hypr_binds.lua` with plain `lua` (which Hyprland depends on).
  - Each file is required as `user.<name>` against a stand-in `hl` that records `hl.bind`/`hl.unbind` with their file and line.
  - Because the files really run, variables, string building and loops work.
  - Limits:
    - `io.popen` reads empty
    - `io.open` only reads
    - `print` goes to stderr
    - a stand-in value lists as empty
    - submap and `hl.on` handlers aren't seen.
- Each dispatcher is mapped onto an action:
  - `exec_cmd` of wpctl/pactl/brightnessctl/playerctl → the media actions
  - the example config's exit command → `exitSession`
  - any other exec → `exec`
  - focus/move/float/pseudo/togglesplit/special/drag → their own actions
  - anything else → the `raw` action (`compositor: hyprland`), with the dispatcher as written.
- Hyprland's example config maps completely.
- **Remapped keys.** Binds from an adopted `00-previous*.lua` on keys axiom's defaults use are moved (`EXAMPLE_KEYS`) and reported in `remapped`. A key in the user's other files was their own choice, so it isn't moved.
  - togglesplit: `SUPER + J` (focus down) → `SUPER + X`
  - the special workspace: `SUPER + S` / `SUPER + SHIFT + S` (WASD's down) → `SUPER + V` / `SUPER + SHIFT + V`
  - float: `SUPER + V` → axiom's `SUPER + Z`.

### What can move
- A call moves only whole:
  - every bind it makes must map (a loop makes several)
  - it may use no option axiom's binds lack (`non_consuming`, …)
  - it must be its own statement in a `user/*.lua` file, not in a `user/lib/` module
  - any variable it's kept in must be unused.

### Committing and removing
1. The binds are committed first (`SettingsManager.commitValues`). `bindsMerged` lets KeybindManager add them to a dirty draft.
2. `remove` then deletes those calls, plus any `hl.unbind` of a moved key (it would unbind the moved bind too).
   - It first writes a dated `<file>.axiom-backup-<date>` copy, keeping the file's mode.
   - It leaves a file alone if `luac -p` rejects the result.
3. Whatever it couldn't delete (`failed`, per file or per call) is taken back out.
   - The binds are committed again as `mergeBinds(before, binds from the sites that went)`, so no key is bound twice.
   - Only the binds that went are sent to `bindsMerged`.

### Duplicates and results
- A key axiom already binds stays one bind. `BindKeys.mergeBinds` puts the moved bind in place of axiom's, because the user's config loads after axiom's layer and so was the one in effect. It does the same in a draft with unsaved edits.
- Reasons are codes (listed in the script's docstring), translated by `BindEditor.reasonText`. `tracked` names files that are in a git repository.
- `lastMerge` shows above the bind list. Its fields are `moved`, `removed`, `kept` (with reasons), `failed`, `remapped`, `tracked`, `errors` and `saveFailed`.
