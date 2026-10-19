# System review: sway
reviewed: a10ba10 2026-10-19  (full)

**Verdict:** The backend is in good shape: the docs match the code almost line for line, SwayFX features are gated on detection throughout, and no rule breaks turned up. The biggest problem is in detached mode: a single bind sway refuses silently drops every axiom bind sent after it. Two more bugs on rarer paths: the user's binds written in sway's block syntax are invisible, and `claim_sway.sh release` can restore a stale backup.

## Major

### 1. One refused bind drops every later bind in the runtime layer  `services/SwayRuntimeLayer.qml:39`
`send` puts all the bind lines into one command list (`SwayManager.runCommands` joins them with `; `). Sway stops a command list at the first `CMD_INVALID`. Checked in a headless SwayFX 0.6 (sway 1.12): `bindsym --no-warn Mod4+Axiom_Bogus_Key nop; bindsym --no-warn Mod4+F20 nop` returns one result (`Unknown key or button 'Axiom_Bogus_Key'`), and the second bind is never made. So in detached mode (and in the runtime fallback of the file modes), one typo'd or unknown key in the Keybinds page silently drops every axiom bind after it in config order. The only sign is one `[SwayIpcManager]` warning. The comment at :37 knows about this for the look but not for the binds. The unbind list has the same problem.
**Fix:** when the batch fails, send each line alone (binding again is harmless with `--no-warn`):
```qml
const send = lines => SwayManager.runCommands(lines, ok => {
  if (!ok && lines.length > 1)
    lines.forEach(line => SwayManager.runCommands([line]));
});
```
Use it for both `unbind` and `bindLines(…)`.

### 2. Binds in sway's block syntax aren't read  `components/methods/SwayConf.qml:651`
Sway accepts `bindsym { … }` blocks: each inner line is prefixed with `bindsym`. Checked: a headless sway loads `bindsym {\n Mod4+F21 nop x\n}` without an error. `configBinds` pushes such a block as an unnamed one and skips its lines, because they don't start with `bindsym`. In detached mode the user's block binds count as free keys, and axiom binds over them with `--no-warn` after every reload. `merge_sway_binds.py:206` also skips them without listing them under `kept`, so the managed Merge doesn't mention them.
**Fix:** when a block opens with `^(bindsym|bindcode)((?:\s+--\S+)*)\s*\{$`, push `{ kind, flags }`, and read each inner line as `<kind> <flags> <line>`. Do the same in `merge_sway_binds.py` (or at least report the lines as `kept`, reason `block`). Add a `tst_SwayConf.test_configBinds` row and a `MergeSwayBinds` case.

### 3. `claim_sway.sh release` restores a stale backup from an earlier claim  `scripts/claim_sway.sh:155`
When `user/` holds no adopted file, release falls back to the newest `config.axiom-backup-*`, whichever claim made it. Reproduced on scratch dirs: config U → claim (`adopted:00-previous.conf`, plus a backup) → release (`restored:user/00-previous.conf`, but the dated backup stays) → the user deletes the config → claim prints `created` → release prints `restored:config.axiom-backup-…` and brings back U instead of writing the fallback. The user gets back a config from an earlier session that the last claim never saw.
**Fix:** make release use only what the last claim set aside. Claim writes the name of what it set aside (`adopted:<name>` / `backup:<name>` / `none`) to a marker, e.g. `user/.backups/claimed` (hidden from `include user/*`). Release reads the marker and, on `none`, writes the fallback.

### 4. The first output after a start with none is not a hotplug  `services/SwayManager.qml:548`
`changed` requires `_outputNames !== ""`, and a start with no outputs leaves it `""`. Connecting the first monitor then never fires `outputsHotplugged`, so `MonitorManager` doesn't apply the profile (sway has no `outputProfiles`).
**Fix:** use a `property bool _outputsRead: false`. Set it in the reply, and compute `changed = root._outputsRead && names !== root._outputNames`.

## Minor

### 5. The doc's `supports` list leaves out `layerFrameSync`  `docs/dev/compositor/sway-backend.md` (› `supports` for sway)
`SwayManager.supports` sets it (`services/SwayManager.qml:73`, and `contract.md:73` names sway). Add it to the list.

### 6. `splitWidthMultiplier` is missing from SwayManager  `services/SwayManager.qml`
`contract.md:32` lists it as required state. Sway leaves it out, and only `CompositorManager`'s `?? 1` covers for that, while `NiriManager:44` declares it. Add `readonly property real splitWidthMultiplier: 1` (sway doesn't split by aspect), or move it to Optional in the contract.

### 7. Special group names may hold `;` or `,`  `components/methods/SwayConf.qml:155`
`toggleSpecial`/`moveToSpecial` accept any `\S+`. In a file, sway splits `nop axiom special toggle a;b` into two commands (and runs `b`), and `_onBinding` splits at the same characters. Accept `^[^;,"']+$` (or `[\w.-]+`) instead.

## Contract
Holds: SwayFX detection (`get_version`'s `sway_original_version`, persisted, retry 2 s doubling to 60 s, `ready` holding back `CompositorConfigManager.live`); every SwayFX line and window effect gated on `fx`. The event mapping (`reload` → `configReloaded`, output-name change → hotplug, `xkb_layout`/`xkb_keymap`, focus, `nop axiom …` bindings), the 50 ms debounce with stale-focus protection, and the 1.5 s settle read. The window, output, workspace and keyboard shapes, and `gapsOut` from the config with its includes. Every primitive as documented. The detached unbinds persisted across QML reloads. `checkLoaded` via the `axiom_layer` mode, file output lines kept until `outputsRead`, `--skip`/`--skip-header` for the user's binds, kept presses for release binds, and the conflict flags matching sway's binding identity. Key capture's runtime mode works (checked headless). Commands keep their order (dispatch queued while a command runs). The IPC listener is a singleton child, so a QML reload leaves no double subscription (the reload warning is the known I3 entry).

## Coverage
Read deeply: SwayManager.qml, SwayConfigWriter.qml, SwayRuntimeLayer.qml, SwayIpcManager.qml, SwayConf.qml, SwayState.qml, SwitcherKeys.qml, sway_config_text.py, merge_sway_binds.py, claim_sway.sh · Outlined: CompositorManager.qml (backend seam), CompositorConfigManager.qml (reload/live seam), RuntimeLayer.qml, CommandManager.qml, WindowSwitcher.qml · Skipped: ConfigTakeover.qml and UserBindMerge.qml (shared drivers with no sway logic), nested.sh (dev tool); tests only grepped.

## Outside the system
- `claim_hyprland.sh` and `claim_niri.sh` have the same `newest_backup` fallback on release (:179, :153), so #3 likely applies there too (not reproduced): recorded in `docs/dev/issues.md`.

## Open findings
None: all seven were fixed after this review (`--fix`, same branch):
1 resends each line alone when a batch fails (`SwayRuntimeLayer._sendEach`); 2 `configBinds` reads `bindsym { … }` blocks and the merge keeps them (`block`); 3 claim records what it set aside (`.axiom-claimed`), release uses only that; 4 `_outputsRead`; 5 doc lists `layerFrameSync`; 6 `splitWidthMultiplier: 1`; 7 special names refuse `; , " '`.
The Hyprland/niri counterpart of 3 is recorded in `docs/dev/issues.md`.
