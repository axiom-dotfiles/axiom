# Recipe: a new bar widget

> **Use when:** adding a widget type users can put on a bar (it shows up in the bar editor's library).
> **Copy from:** `components/bar/widgets/IdleInhibitor.qml` (service toggle, no popout), `components/bar/widgets/Weather.qml` (polled data + its own popout), `components/bar/widgets/Updates.qml` (an `acquire` request from settings, both buttons, `extraData`); schema `definitions.IdleInhibitorWidget`.
> **Docs:** [bar/composition](../dev/bar/composition.md), [bar/widget-style](../dev/bar/widget-style.md), rules in `components/bar/widgets/AGENTS.md`; generated: [config/BarWidgets](../dev/config/BarWidgets.md).

## Files to touch
1. `components/bar/widgets/<Type>.qml`: the widget. The file name is the type const.
2. `config/json/config.schema.json`: a `<Type>Widget` entry in `definitions`, and `{ "$ref": "#/definitions/<Type>Widget" }` appended to `definitions.BarWidget.oneOf`.
3. `config/i18n/*.json`: nothing to do: the pre-commit hook adds the new keys, empty, to every language and the template (the title, descriptions and the type's `description`, which is its library label, are keys).
4. If it opens a popout of its own: `components/content/<Name>.qml` ([bar-popout](bar-popout.md)).
5. If it needs data that's polled: the service's `acquire`/`release` ([service](service.md)).

## Skeleton
```qml
pragma ComponentBehavior: Bound
import QtQuick

import qs.config
import qs.services
import qs.components.hosts.popout

// <One sentence: what it shows and what clicking does.>
BarIconWidget {
  id: root

  icon: FooManager.active ? "toggle_on" : "toggle_off"
  text: I18n.tr(FooManager.active ? "On" : "Off")
  showText: properties.showLabel
  accentColor: Theme.resolveColor(FooManager.active ? properties.activeColor : properties.inactiveColor)

  clickable: true
  onClicked: FooManager.toggle()

  // Only with a popout of its own (content/FooDetails.qml)
  PopoutAnchor {
    hitArea: root.hitArea
    popoutName: "FooDetails"
    active: EdgeMenusConfig.opensOwnPopout(root.properties)
  }
}
```
Schema entry (in `definitions`):
```json
"FooWidget": {
  "type": "object",
  "x-icon": "toggle_on",
  "x-libraryGroup": "System",
  "required": ["type"],
  "additionalProperties": false,
  "properties": {
    "type": { "const": "Foo", "description": "Foo" },
    "visible": { "type": "boolean" },
    "layout": { "$ref": "#/definitions/WidgetLayout" },
    "properties": {
      "type": "object",
      "additionalProperties": false,
      "properties": {
        "showLabel": { "type": "boolean", "title": "Show label", "default": false },
        "showPopout": { "type": "boolean", "title": "Popout", "default": true, "description": "Show the details when hovered." },
        "popoutMenu": { "type": "string", "title": "Open instead", "default": "", "x-options": "edgeMenus", "x-emptyLabel": "Its own popout", "description": "An edge menu to open in place of the popout.", "x-showIf": { "showPopout": true } },
        "activeColor": { "type": "string", "title": "Active color", "x-options": "colors", "default": "", "x-emptyLabel": "Auto", "x-autoColor": "accent", "x-showIf": { "$bar.widgetStyle": { "not": "plain" } } },
        "inactiveColor": { "type": "string", "title": "Inactive color", "x-options": "colors", "default": "", "x-emptyLabel": "Auto", "x-autoColor": "off", "x-showIf": { "$bar.widgetStyle": { "not": "plain" } } },
        "foregroundColor": { "type": "string", "title": "Text color", "x-options": "colors", "default": "base00", "x-showIf": { "$bar.widgetStyle": "filled", "$bar.widgetGrouping": { "not": "merged" }, "$bar.widgetTextColor": "" } }
      }
    }
  }
}
```
Without a popout of its own, `showPopout` is `"title": "Menu popout", "default": false, "description": "Open an edge menu when hovered."` and `popoutMenu` has `"title": "Menu", "x-emptyLabel": "None", "description": "The edge menu to open."` (as `IdleInhibitorWidget`).

## Steps
1. Write the schema entry first and add its `$ref` to `definitions.BarWidget.oneOf`. Pick `x-libraryGroup` from the root's `x-libraryGroups` (`Desktop`, `Time & weather`, `Media & audio`, `Network & devices`, `System`, `Tools`, `Look & layout`, `Session`).
2. Write `components/bar/widgets/<Type>.qml` with its purpose comment above the root.
3. Read every setting as `properties.<key>` (always present: defaults are filled at load).
4. Polled data: a request built from `properties` only (copy `Updates.qml`'s `updatesRequest`), acquired in `Component.onCompleted` and on its change, released in `onDestruction`.
5. Verify.

## Gotchas
- `BarWidgetHost` handles `popoutMenu` itself (an edge menu instead of the popout): the widget's own `PopoutAnchor` is gated by `EdgeMenusConfig.opensOwnPopout(root.properties)`, never by `properties.showPopout` alone.
- Every widget but Button, Separator and the tray has `showPopout` / `popoutMenu`, even without a popout of its own (they open an edge menu).
- A label that ticks (a countdown, an elapsed time, any number changing every second) sets `steadyDigits: true` on its `BarIconWidget`: tabular digits, sized by its digit count, so the bar doesn't resize every tick (only when it gains or drops a digit). Copy `Pomodoro.qml`.
- Sizes come from the bar (`barConfig.widgetSize`, `barConfig` padding/spacing/font/radius), never `Widget.*`. `BarIconWidget` already does this; a widget drawing more must too.
- A color field the bar should pick when empty has `"default": ""`, `"x-emptyLabel": "Auto"` and an `x-autoColor` role (`accent`, `alt`, `warning`, `critical`, `off`, `neutral`). `tst_Config` checks these.
- Color fields show only in the bar looks they do something in (`$bar.<key>` conditions; the rules are in [bar/widget-style](../dev/bar/widget-style.md#which-color-fields-show)): the state colors that feed `accentColor` hide under Plain text, and `foregroundColor` shows only when filled, not merged, with the bar's text color Auto. A widget without an icon shows its color only boxed and not merged, or underlined (`TimeWidget`).
- The type const must not match a `components/content/` file another file sees alongside it (e.g. a `Battery` widget and `Battery` content): `check_structure.py` errors.
- `hidden: true` hides the widget and disables its clicks; use it for "hide when empty" settings.
- `onClicked` gets the button when `acceptedButtons` lists more than one (`Updates.qml`).

## Verify
- `scripts/dev/verify.sh`
- `scripts/run_tests.sh Config` (every default is valid; auto colors)
- Add it to a bar in the bar editor and look: `scripts/dev/shot.sh page BarEditor`.

## Docs to update
- [bar/widget-style](../dev/bar/widget-style.md) only if it introduces a new base or color rule.
- `docs/features.md` bar widget list, if it lists widgets.
