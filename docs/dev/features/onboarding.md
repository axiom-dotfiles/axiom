# Onboarding

> **Files:** `services/OnboardingManager.qml`, `shell/Onboarding.qml`, `components/surfaces/onboarding/OnboardingWindow.qml`, `components/surfaces/onboarding/pages/HyprlandPage.qml`, `services/DependencyManager.qml`, `components/views/settings/OnboardingCard.qml`
> **Config:** none of its own (pages write other sections); state in `config/state/onboarding.json`
> **Related:** [Hyprland config modes](../hyprland/config-modes.md), [Monitors](../hyprland/monitors.md), [Greeter install](greeter-install.md), [Pages and grid](../overlay/pages-and-grid.md)

The first-run onboarder: a paged window that sets up the look, Hyprland mode, monitors, apps and integrations.

### When it opens
- When there was no config.json (`ConfigManager.firstRun`, set by `_existsCheck`).
- After a restart, until the user finishes or skips it.
- State lives in `config/state/onboarding.json`: `{ completedVersion, step }`.
  - A config with no state file is never prompted.
  - Bump `version` when a page is worth showing to existing users.
- The step and the chosen Hyprland mode live in a `PersistentProperties`.

### Window
- `shell/Onboarding` → `surfaces/onboarding/OnboardingWindow`, with pages in `onboarding/pages/`.
- The window is a `hosts/overlay/ReservedAreaWindow`, like the overlay's.
- It uses the same `OverlayGrid`, so the Welcome page's `Overlay.size` setting shows on it.
- Its pages shrink as much as the overlay's first page does there (`GridPlacement.fitScale`). Cards therefore show at the overlay's real size, even on a screen too small for it.
- The step bar is the overlay's `OverlayPageNavigator`.

### Applying
- Pages apply as the user goes:
  - `SettingsManager.commitValues({ dottedPath: value })`; or
  - `forms/SettingRows`, which shows config paths as `SchemaField` rows and saves them debounced.
- Only the Hyprland mode waits for Finish.

### Hyprland page
- **`configState`:** `none` | `stock` | `custom` | `ours` | `blocked` | `legacy`. It comes from `checkManaged()` plus a `hyprland.conf` check.
- **The three modes** are always shown, with `OptionCard.tag`:
  - `managed`: Recommended
  - `included`: For complex setups
  - `detached`: For testing
- **Starting mode:** the page starts on `recommendedMode` (`chosenMode` falls back to it):
  - `managed` for Hyprland's generated example config (`stock`), for no config (`none`), or for axiom's own (`ours`);
  - `detached` for any config of the user's (`custom`, `legacy`, `blocked`), which it then leaves alone.
- A blocked managed card says why (`blockedReason`).
- **Hookups:** for included and detached it shows `forms/IntegrationHookup` for `hyprlandInclude` / `hyprlandAutostart` (copy, or Apply after a backup).
  - `includeDone` / `autostartDone` drop the "won't start axiom" warnings, both there and on Finish.
- See [Hyprland config modes](../hyprland/config-modes.md).

### Monitors
- On a first run with a stock or missing config, `MonitorManager.useWholeScale()` saves a layout with every fractional scale rounded down to a whole one (`MonitorLayout.wholeScaleRules`).
  - The example config's `scale = "auto"` is often 1.25 or 1.5.
  - A scale of 2 stays, so a HiDPI panel stays readable.
- It doesn't do this if a layout is already saved, or if no scale is fractional.
- See [Monitors](../hyprland/monitors.md).

### Other pages
- It reuses the Monitors view, `WallpaperPicker` and `ThemePicker` as they are.
- The Look page's folder check, create and open are `WallpaperManager.checkFolder()` / `folderImages` / `createFolder()` / `openFolder()`.
- `DependencyManager.check(commands)` / `found` / `tools` say what's installed.
- The Integrations page ends with the login screen (`forms/GreeterSetup`, see [Greeter install](greeter-install.md)), set up only from its Install button.
  - The same page recommends [Idle](idle.md) and [Polkit](polkit.md).

### Entry points
- IPC `onboarding`:
  - `open`, `close`;
  - `reset`, which opens it at the next start;
  - `goTo <step>`.
- Launcher `/welcome`.
- Settings → General's `OnboardingCard`.

### Testing
- Use `ipc call onboarding goTo <n>` plus grim screenshots.
- Never delete the real config.json to test it. (Rule: AGENTS.md › Never, while testing.)
