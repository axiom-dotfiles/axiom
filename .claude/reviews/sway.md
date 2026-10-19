# sway
reviewed: a10ba10 2026-10-19  (full)

The backend is in good shape: the docs match the code almost line for line, SwayFX features are gated on detection throughout, and no rule breaks turned up. The seven findings of this review (a refused bind dropping later binds in detached mode, `bindsym { … }` blocks not read, `claim_sway.sh release` restoring a stale backup, the first output after a start with none not counted as a hotplug, and three smaller ones) are fixed.

## Open findings
None.

## Contract
Holds: SwayFX detection (`get_version`'s `sway_original_version`, persisted, retry 2 s doubling to 60 s, `ready` holding back `CompositorConfigManager.live`); every SwayFX line and window effect gated on `fx`. The event mapping (`reload` → `configReloaded`, output-name change → hotplug, `xkb_layout`/`xkb_keymap`, focus, `nop axiom …` bindings), the 50 ms debounce with stale-focus protection, and the 1.5 s settle read. The window, output, workspace and keyboard shapes, and `gapsOut` from the config with its includes. Every primitive as documented. The detached unbinds persisted across QML reloads. `checkLoaded` via the `axiom_layer` mode, file output lines kept until `outputsRead`, `--skip`/`--skip-header` for the user's binds, kept presses for release binds, and the conflict flags matching sway's binding identity. Key capture's runtime mode works (checked headless). Commands keep their order (dispatch queued while a command runs). The IPC listener is a singleton child, so a QML reload leaves no double subscription (the reload warning is the known I3 entry).

## Coverage
Read deeply: SwayManager.qml, SwayConfigWriter.qml, SwayRuntimeLayer.qml, SwayIpcManager.qml, SwayConf.qml, SwayState.qml, SwitcherKeys.qml, sway_config_text.py, merge_sway_binds.py, claim_sway.sh · Outlined: CompositorManager.qml (backend seam), CompositorConfigManager.qml (reload/live seam), RuntimeLayer.qml, CommandManager.qml, WindowSwitcher.qml · Skipped: ConfigTakeover.qml and UserBindMerge.qml (shared drivers with no sway logic), nested.sh (dev tool); tests only grepped.

## History
- 2026-10-19 full: 7 findings (4 major, 3 minor), fixed in 2362cd6; the same release fallback in `claim_hyprland.sh`/`claim_niri.sh` recorded in `docs/dev/issues.md`.
