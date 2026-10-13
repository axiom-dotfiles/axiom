# Bar widgets (`components/bar/widgets/`)

A file here is a bar widget type: `<Type>.qml` is loaded by `BarContainer` from `"widgets/" + type + ".qml"`. Docs: `docs/dev/bar/composition.md`, `widget-style.md`, `widget-shapes-runs.md`.

- **A new widget = this file + a `<Type>Widget` definition in `config/json/config.schema.json` + its `$ref` in `definitions.BarWidget.oneOf`.** Copy `IdleInhibitor.qml` (service toggle), `Weather.qml` (polled data + popout) or `Updates.qml` (request, both buttons, `extraData`), and the `IdleInhibitorWidget` schema entry.
- Icon + label widgets extend `BarIconWidget` (`icon`, `text`, `showText`, `accentColor`, `clickable`, `onClicked`); others extend `BarWidget`. Both get `barConfig`, `panel`, `screen`, `properties`.
- The widget's settings are `properties.<key>` (schema `properties.properties`); bar-level values are `barConfig.<key>` (some are derived by `Bar.enrichBarConfig`, not schema keys).
- **Sized by the bar**: cross size `barConfig.widgetSize`; padding, spacing, font size and radius from `barConfig`, never `Widget.*`.
- Colors: config names through `Theme.resolveColor(properties.X)`; color fields use `x-options: "colors"` and, when the bar should pick one, `x-autoColor` (checked in `tst_Config`).
- Schema entry needs `x-icon`, an `x-libraryGroup` from the root's `x-libraryGroups`, `required: ["type"]`, `type: { const, description }` (the description is its library label), `visible`, `layout: { $ref WidgetLayout }`. Every widget but Button, Separator and the tray has `showPopout` / `popoutMenu` (`x-options: "edgeMenus"`).
- A popout opens through `PopoutAnchor { hitArea: root.hitArea; popoutName: "<Name>"; active: EdgeMenusConfig.opensOwnPopout(root.properties) && … }`; the content is `components/content/<Name>.qml`.
- Polled data: `readonly property var <x>Request: ({ … })` built from `properties` only; `acquire` in `Component.onCompleted` and on its change, `release` in `onDestruction`.
- A widget must never see a same-named content type (e.g. widget `Battery` and content `Battery`): `check_structure.py` catches it.
- After: `/usr/lib/qt6/bin/qmlformat -i`, `scripts/check_structure.py`, `scripts/run_tests.sh Config`, `scripts/check_i18n.py`, `scripts/log.sh`.
