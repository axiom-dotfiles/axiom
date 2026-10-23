# Recipe: a new overlay view type (incl. tool pages)

> **Use when:** adding a page type to the overlay. A *tool page* (`x-tool: true`: Settings, BarEditor, Themes, Keybinds, Monitors, CalendarPage) is a hand-built page that is always in config.
> **Copy from:** `components/views/Settings/Settings.qml` (a small `BaseView` page), `components/views/Themes/Themes.qml`; schema `definitions.CalendarOverlayView`; migration `ConfigMigration._v45ToV46` with test `test_v46_adds_the_calendar_page_once` in `tests/tst_Config.qml`.
> **Docs:** [overlay/pages-and-grid](../dev/overlay/pages-and-grid.md), [core/streamed-building](../dev/core/streamed-building.md), [core/editors-pattern](../dev/core/editors-pattern.md) (for an editor page), rules in `components/views/AGENTS.md`; generated: [config/OverlayViews](../dev/config/OverlayViews.md).

## Files to touch
1. `components/views/<Type>/<Type>.qml`: the page; its pieces in `components/views/<type>/` (lower-case folder).
2. `config/schema/definitions/views/<X>OverlayView.yaml` (and its name in `config/schema/index.yaml`'s `definitions`), its `$ref` in the `oneOf` of `config/schema/definitions/views/OverlayView.yaml`.
3. Tool page only:
   - `config/schema/sections/Overlay.yaml`'s `views` `default` array: append `{ "type": "<Type>" }`;
   - `components/methods/ConfigMigration.qml`: a step appending it to existing configs, plus a `version` bump ([migration](migration.md));
   - `tests/tst_Config.qml`: a `test_v<N>_adds_the_<x>_page_once` case;
   - `services/LauncherCommands.qml`: a way to open it (below);
   - `docs/usage.md`: the **Pages** row of the launcher command table.
4. `config/i18n/*.json`: nothing to do: the pre-commit hook adds the new keys, empty, to every language and the template.

## Skeleton
```qml
pragma ComponentBehavior: Bound
import QtQuick
import qs.services
import qs.components.views.foo

// <What the page is for and where its state lives (FooManager).>
BaseView {
  id: root

  Component.onCompleted: FooManager.ensureLoaded()

  // Each panel streamed in as the page opens, at its size from the start
  StreamedLoader {
    Layout.preferredWidth: root.sideWidth
    Layout.preferredHeight: root.pageHeight
    label: "foo sidebar"
    sourceComponent: FooSidebar {}
  }

  StreamedLoader {
    Layout.preferredWidth: root.editorWidth
    Layout.preferredHeight: root.pageHeight
    label: "foo editor"
    sourceComponent: FooEditor {}
  }
}
```
(`import QtQuick.Layouts` and `qs.components.reusable` too.) The page shows at once and its panels fill in over the next frames: wrap long or repeated parts inside them the same way, build nothing hidden, and check it with `scripts/dev/bench_overlay.sh FooPage` (no `Built … in` line over a frame or two). See [streamed-building](../dev/core/streamed-building.md).
Schema:
```json
"FooOverlayView": {
  "type": "object",
  "x-icon": "build",
  "x-tool": true,
  "required": ["type"],
  "additionalProperties": false,
  "properties": {
    "type": { "const": "FooPage", "description": "Foo" },
    "visible": { "type": "boolean" }
  }
}
```
Migration step (tool page):
```js
// v<N> added the Foo page: every config gets it once
function _v<M>ToV<N>(config, changes) {
  const views = config.Overlay?.views;
  if (!Array.isArray(views) || views.some(view => view?.type === "FooPage"))
    return config;
  views.push({ "type": "FooPage" });
  changes.push("Overlay.views: added the Foo page");
  return config;
}
```

## Steps
1. Schema first: the definition, its `$ref`, and for a tool page the `Overlay.views` default entry. Then the migration step and version bump, then its test.
2. Pick a type const that's the file name and doesn't collide with a content type (`CalendarPage`, not `Calendar`).
3. Write the view on `BaseView`: size from `grid`, `pageHeight`, `sideWidth`, `editorWidth`, `cardPageWidth`; `viewConfig` is its entry in `Overlay.views`.
4. Opening it from the launcher: add `root._page("<name>", [aliases], "<Type>", "<Description>")` to `LauncherCommands.list`, and add `I18n.tr("<Description>")` to the declaration comment in `_page`. If the page should open on something chosen first, pass `before`; or give it its own command calling a service, as `/calendar` does (`CalendarManager.openPage()`, which falls back to a page holding the Calendar module).
5. Verify.

## Gotchas
- A new subfolder imported only from URL-loaded files isn't scanned until qs restarts (`module "qs.components.views.foo" is not installed`): ask the user to restart.
- Editor pages: the manager owns the draft and the selection (`select*()`); the page never assigns them ([core/editors-pattern](../dev/core/editors-pattern.md)).
- The page exists only while it or a neighbour is shown: lasting state goes in a service.
- `x-icon` is also the launcher command's glyph (`OverlayConfig.viewIcon(type)`).
- The migration step must be idempotent and must check its input's shape (`Array.isArray`).

## Verify
- `scripts/dev/verify.sh`
- `scripts/run_tests.sh Config` (defaults, the migration test, `test_migration_is_idempotent`)
- `scripts/dev/shot.sh page <Type>`

## Docs to update
- [overlay/pages-and-grid](../dev/overlay/pages-and-grid.md) (the tool page list), the feature's doc, `docs/usage.md`.
