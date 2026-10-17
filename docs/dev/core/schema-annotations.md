# Schema and its annotations

> **Files:** `config/json/config.schema.json`, `components/methods/SchemaLayout.qml`, `components/methods/SchemaValidation.qml`, `components/forms/SchemaField.qml`, `components/methods/HyprLua.qml`
> **Config:** every section
> **Related:** [Settings page](settings-page.md), [Saved configs and sharing](saved-configs-sharing.md), [Config manager](config-manager.md), [Config readers](config-readers.md), [Hyprland config modes](../hyprland/config-modes.md)

The schema is the single source of truth for config: shape, `default`s (there is no separate defaults file) and the generated settings page (`views/Settings.qml`). This doc is the complete list of `x-*` annotations. (Rule: AGENTS.md › Config.)

### Basics
- Adding a setting = a schema entry with a `default` + a reader property.
- Changing the layout of existing config = bump `version` + a `ConfigMigration` step + a test.
- The live file is `~/.config/axiom/config.json` (`$XDG_CONFIG_HOME`, UI-owned).
- A schema reaches QML as a map, whose keys come out sorted, so order always comes from `x-order`.
- The settings page, forms and editors read the annotations: add an annotation rather than a hand-kept list in QML.
- A `$ref` may carry keys beside it (`default`, `title`, …) that override the definition's (`SchemaValidation._resolve`). `Lockscreen.layout` and `Greeter.layout` share `definitions/ScreenLayout`, each with its own default modules.
- `oneOf`s (bar widgets, overlay views and modules) are discriminated by `type`.

### Placement
- `x-settings: false`: hides a key from the settings page (edited elsewhere, or UI-owned state).
- `x-category` (on a top-level section): names its sidebar category.
- `x-categories` (root, `[{ name, icon, page }]`): orders the categories and gives their icons (`SchemaLayout.categories`). A category left out comes last, with a generic icon.
  - `page` is a hand-built part shown after the category's cards (`views/settings/<page>.qml`), so a category can have no sections. Example: Maintenance's `SavedConfigsSection`; see [Saved configs and sharing](saved-configs-sharing.md).
- `x-links` (on a section): page types it links to (`Themes`, `Layouts`, or a view type). The link buttons take the page's label and icon from `OverlayConfig.viewLabel` / `viewIcon`.
- `x-order` (on an object): the keys shown first, in order. This applies to its form, or to its settings cards, whose order is their first field's.
- `x-group`: puts a field on a card of that name. One section or object can make several cards.
  - The bar and edge menu editors group a `Bar`'s / `EdgeMenu`'s own fields the same way (`SchemaLayout.objectGroups`, as `Bar.fieldGroups` / `EdgeMenusConfig.fieldGroups`).
- `x-cardPerField: true` (on a section): each direct field becomes a card of its own, titled and described by the field, sorted by title, a switch's row labelled "Enabled" (`row.label`, `row.description` override the field's in `SchemaField`). The section's description gets a card first. Example: `ThemeIntegrations`, one card per app.
- `x-scope` (`look` | `personal` | `machine`, inherited, root `machine`): what a snapshot, example, import or export carries. See [Saved configs and sharing](saved-configs-sharing.md).
  - A new setting inside a look section that names a monitor, path, account or command needs `machine` or `personal`.
- `x-libraryGroups` (root) lists in order the groups the bar editor's and layouts editor's libraries sort their types into (by category).
  - Each bar widget and overlay module definition joins one with `x-libraryGroup` (`methods/LibraryOrder`, `reusable/TypeLibrary`).
  - `check_structure.py` errors on an unknown group.

### Hand-built parts
- `x-card: "<Name>"` (section): adds `views/settings/<Name>Card.qml` as its first card.
  - `x-cardFolds: true`: it folds like the generated cards and joins Fold all, getting its group key `<Section>:<Name>` as `foldKey`.
  - `check_structure.py` does not verify the file exists: a typo only shows in `scripts/log.sh`.
- `x-intro: "<Name>"`: puts `views/settings/<Name>.qml` at the top of the section's own card, above its fields (NightLight's `NightLightStatus`).

### Behaviour
- `x-showIf`: hides a field unless a condition holds. `SchemaField` evaluates it (`SchemaLayout.showIfHolds`), so it works in every form; on a nested object it hides that object's cards.
  - Form: `{ sibling: value | [values] | { not: value } | { notEmpty: true } }`. Every key must hold.
  - `anyOf: [conditions]` holds when one of them does. Example: the OSD's `alongEdge`, shown only while its bars run along its edge.
  - A key starting with `/` is a dotted path from the config root (e.g. `"/Workspaces.layout"`), read through `SettingsManager.configValueAt`.
  - **Compositor.** Two `/` keys read the running compositor instead: `"/$supports.<capability>": true` (`CompositorManager.supports`) and `"/$compositor": "<kind>"`. See [The compositor](../compositor/README.md) › Hiding what a compositor can't do.
  - On a whole section, `x-showIf` (with `/` keys only) takes the section out of its settings category when it fails (`SchemaLayout.categories`). The `Hyprland` section needs `configModes`.
- `x-enumShowIf` (`{ optionValue: condition }`): hides enum options whose condition doesn't hold. The current value stays listed.
- `x-enabledIf`: as `x-showIf`, but a field whose condition fails stays shown, greyed out, its value kept and not editable (`SchemaField.allowed`), with why above its description. Use it for what the compositor can't do (`"/$supports.windowBlur": true`), so the setting is still found and says what would: the note is `CompositorManager.unsupportedNote(capability)` (the backend's `unsupportedHint` adds what can, e.g. "SwayFX can."), or "<Compositor> only." for `/$compositor`. Only a row shown on its own says it: a row that a sibling shows (a part's fields, `x-showIf: { part: true }`) is greyed without repeating the note under its switch. `SchemaLayout.compositorAllows` counts it too, so the launcher's `/config` doesn't offer such a setting.
  - `x-disabledNote`: the note instead (English, translated); `false` for none, where the section's `x-intro` says why (the Workspaces section under niri).
- `x-beside: true`: puts a field beside the one before it on its settings card, each half wide (`SettingsGroupCard`'s two-column grid; Workspaces' rows beside columns). Give the pair the same `x-showIf`.
- `x-applyOnSave`: keeps a setting in the draft until Save instead of applying it live (Hyprland's `mode`, which can take over files).
- `x-snapshot: true`: a machine setting a saved snapshot carries too (the wallpaper setup: wallpapers, folder, mode, rotation, light/dark wallpapers, theme schedule), since a snapshot restores on the PC it was saved on. Exports and examples still leave it out. See [Saved configs and sharing](saved-configs-sharing.md).
- `x-takeover: true`: a setting that takes something over on this PC (Hyprland mode, locker, idle, polkit, greeter). Loading or importing a config never changes it; only its own card does. See [Saved configs and sharing](saved-configs-sharing.md).

### Controls
- `x-options`: a dynamic option list.
  - `"colors"`: a picker over `base00`–`base0F`, read with `Theme.resolveColor` (which also takes semantic names and hex).
  - `"screens"`: a monitor. Empty means the primary monitor, resolved by `General.screensNamed` (bars in `Bar.expandBars`, docks, edge menus). Docks and OSDs pick all monitors through `monitors` instead.
  - Others: `"languages"`, `"edgeMenus"`, `"overlayPages"`, `"notes"`, `"timezones"`, `"calendars"`, `"chatProviders"`, `"chatPresets"`, `"cursorThemes"` (`SettingsManager.optionsFor`).
- `x-emptyLabel`: offers or renames the empty value under that label.
  - On a color: automatic (a bar's `widgetTextColor`).
  - On `"screens"`: renames empty where it means something else, as in `General.primaryMonitor` itself.
- `x-allScreens`: adds All monitors (`"*"`) to a `"screens"` picker.
- `x-enumLabels` (`{ value: label }`): labels shown instead of raw enum values in dropdowns.
- `x-suggestions` (e.g. `"audioApps"`): chips under a text field (`SettingsManager.suggestionsFor`).
- `x-multiline: true`: a growing text area.
- `x-control`:
  - `"slider"` | `"stepper"`: overrides the integer control choice (below).
  - `"readonly"`: shows a string with a copy button instead of a field (an edge menu's `id`).
  - `"folder"`: a string with a Browse button opening the desktop's folder picker ([File picker](file-picker.md); the wallpaper, notes, screenshot and recording folders, Claude usage's `configDir`, System stats' `diskPath`). It hands back `~/…`, so whatever reads the setting expands `~` (`Paths.expandHome`).
  - `"search"`: a long option list (e.g. `"timezones"`) is typed into to filter it (`SchemaField`; the Clock module's and World clocks' `timezone`).
- Integers render through `forms/SchemaNumberField`:
  - a slider with a value box for 7–200 steps, else a stepper, with ±10 buttons past 20 steps
  - steppers commit debounced, sliders on release
  - `x-unit` (`px`, `%`, `ms`, …) is shown after the value.
- `x-auto: { value, start }`: a switch in front of an integer whose `value` means automatic. Turning it on stores `start`, then the number shows (an edge menu's `padding`, `triggerLength`).

### Types (bar widgets, overlay modules, views)
- `x-icon`: a Material Symbols name on bar widget, overlay module and view definitions.
- On overlay modules:
  - `x-defaultSize` (`[w, h]` in grid units, four to a card): the size it's added at.
  - `x-minSize`: the least a drop into a gap shrinks it to; half the default when left out (`OverlayConfig.minSize`).
  - `x-hosts`: `overlay`, `edgeMenu`, `lockscreen`, `greeter`, `desktop`. The first two when left out, so the lock screen, the greeter and the desktop only take modules that list them.
  - `x-keyboard: true`: the module takes typing. The desktop, which otherwise never takes the keyboard, takes it on a click while its layout shows one (`OverlayConfig.moduleInfo(type).keyboard`, `ScreenLayoutView.wantsKeyboard`). Needed for a typing module to list `desktop` in `x-hosts`.
  - `x-required`: part of every grid on its hosts; never removed, duplicated or in the library (the lock screen's `Password`).
  - `x-canvasDetail`: a module property the layouts editor shows on its tile (a list joined). `x-canvasFill`: a color property the tile is filled with (`OverlayConfig`).
- `x-tool: true` on the hand-built view types: the navigator's tool group.
- `x-needs: "<capability>"` on a view type: the page is left out (and its launcher command unlisted) unless `CompositorManager.supports` has it (Keybinds, Monitors).
- `x-autoColor` (`accent`, `alt`, `warning`, `critical`, `off`, `neutral`): a bar widget color picked by its bar when left empty (`Bar.autoColorFields`, `methods/BarAutoColors`). See [Bar widget style](../bar/widget-style.md).

### Hyprland options (`x-hypr*`, `methods/HyprLua`)
- `x-hypr`: the option's dotted path (or a list of paths). The field becomes one value of a nested `hl.config({...})` table.
- `x-hyprScale`: a factor for integers shown scaled (0.01 for a percent).
- `x-hyprValue`: how the value is converted.
  - `"int"`: a boolean as 0/1
  - `"number"`: an enum of numbers written as strings
  - `"emptyIsDefault"`: `"default"` → `""`
  - `"color"`: a theme color name as `rgba(hex + x-hyprAlpha)`, with `"ff"` unless given.
- `x-hyprAlways`: written even when it's the schema default. Other fields are only written once changed, so Hyprland's own default (and the user's files) stay in charge otherwise.
- `x-hyprIf`: a boolean sibling; the field is written (default or not) only when that sibling is on.

### Sway commands (`x-sway*`, `methods/SwayConf`)
- `x-sway`: the sway command with `{}` for the value (`"input type:keyboard repeat_rate {}"`). Written under the same rules as `x-hypr`: when its `x-hyprIf` sibling is on, else once changed from the default.
- `x-swayValue`: how the value is written: `"enabled"` (a boolean as `enabled`/`disabled`), `"yesNo"` (`yes`/`no`), `"enableDisable"` (`enable`/`disable`), `"raw"` (as it is, unquoted). Without one, the value is quoted as one argument (`SwayConf.quote`).
- `x-swayMap`: `{ value: sway's word }` for an enum whose names differ from sway's; a value missing from it is left out.
- `x-swayScale`: a factor, as `x-hyprScale`.
- `x-swaySkip`: a value written as nothing (sway's own default stays), e.g. `"default"`.
- `x-swayConfigOnly: true`: sway takes the command only from a config file (`xkb_numlock`): left out of what's sent at runtime.

### niri config nodes (`x-niri*`, `methods/NiriConf`)
- `x-niri`: the dotted path of the node in niri's config (`"input.keyboard.repeat-rate"`, `"layout.default-column-width.proportion"`), its value the node's argument. Written under the same rules as `x-hypr` (`CompositorLayer.annotatedFields`): when its `x-hyprIf` sibling is on, else once changed from the default; a managed config's options every one.
- `x-niriValue`: `"flag"` (a boolean as the node alone when on, left out when off: niri has no `false` for a flag) or `"float"` (written with a point, where niri wants a float).
- `x-niriScale`: a factor, as `x-hyprScale`.
- `x-niriSkip`: a value written as nothing (niri's own default stays), e.g. `"default"` or `0`.
- `x-niriMap`: `{ value: niri's argument }` for an enum whose names differ; a value missing from it is left out.
- Details: [Sway backend](../compositor/sway-backend.md).

- `x-greeter: true` on an `Input` option: the greeter's Hyprland takes it (`methods/GreeterBundle`). See [Greeter install](../features/greeter-install.md).
- Details: [Hyprland config modes](../hyprland/config-modes.md), [Window look](../compositor/window-look.md).

### Theme integrations
- `x-hookup` (on a `ThemeIntegrations` boolean): how the integration hooks into its app (targets, place, text).
- `x-hookupNote`: a note shown with it.
- `x-profiles`: profile locations to search (Firefox and its forks; `scripts/integration_hookup.py`, `theme_firefox.sh`).
- See [Theme integrations](../theming/theme-integrations.md).
