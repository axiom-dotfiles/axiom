# sway
reviewed: 158ac3d 2026-10-19  (incremental since a10ba10)

The backend is in good shape. The 2362cd6 fixes hold; this review's two findings (the detached layer's per-line resend queued after the next list, so a refused key unbound axiom's other keys on the next apply, and swaybar's `bar { }` binds read as the user's) are fixed.

## Open findings
None.

## Contract
Holds: SwayFX detection (`get_version`'s `sway_original_version`, persisted, retry 2 s doubling to 60 s, `ready` holding back `CompositorConfigManager.live`), and every SwayFX line and window effect gated on `fx`. The event mapping (`reload` → `configReloaded`, output-name change → hotplug including the first output after a start with none, `xkb_layout`/`xkb_keymap`, focus, `nop axiom …` bindings), the 50 ms debounce with stale-focus protection, and the 1.5 s settle read. The window, output, workspace and keyboard shapes, and `gapsOut` from the config with its includes. Every primitive as documented; special-workspace names exclude `; , " '`. The detached unbinds persist across QML reloads. `checkLoaded` via the `axiom_layer` mode, file output lines kept until `outputsRead`, `--skip`/`--skip-header` for the user's binds, kept presses for release binds, and conflict flags matching sway's binding identity. `configBinds` reads `mode` and `bindsym { }` blocks and leaves out other blocks' lines (`bar { }`); the merge keeps block binds (`block`). Release restores what `.axiom-claimed` records (falling back to the newest only with no record). Key capture's runtime mode works (checked headless). Commands keep their order (`SwayIpcManager` queue; a callback runs before the next queued command), and the detached layer's lists each wait for the one before (`_sendEach`'s `then`). The IPC listener is a singleton child.

## Coverage
Read deeply (2026-10-19 full): SwayManager.qml, SwayConfigWriter.qml, SwayRuntimeLayer.qml, SwayIpcManager.qml, SwayConf.qml, SwayState.qml, SwitcherKeys.qml, sway_config_text.py, merge_sway_binds.py, claim_sway.sh; incremental: the 2362cd6 diff plus SwayIpcManager's queue and RuntimeLayer.apply. Outlined: CompositorManager.qml, CompositorConfigManager.qml, RuntimeLayer.qml, CommandManager.qml, WindowSwitcher.qml. Skipped: ConfigTakeover.qml, UserBindMerge.qml (shared drivers), nested.sh (dev tool).

## History
- 2026-10-19 full: 7 findings (4 major, 3 minor), fixed in 2362cd6; the same release fallback in `claim_hyprland.sh`/`claim_niri.sh` recorded in `docs/dev/issues.md`.
- 2026-10-19 incremental since a10ba10: 2 findings (1 major, 1 minor); fixed in the commit after 158ac3d.
