# Views (`components/views/`)

Overlay page types: `<type>.qml` is loaded by `OverlayPages` for each entry of `Overlay.views`; a view's pieces live in `views/<type>/` (lower-case folder). Docs: `docs/dev/overlay/pages-and-grid.md`, `docs/dev/core/editors-pattern.md`, `docs/dev/core/settings-page.md`.

**Recipe:** `docs/recipes/overlay-view.md` / `docs/recipes/settings-card.md`; verify with `scripts/dev/verify.sh`.

- Views extend `BaseView` (`grid`, `viewConfig`, `pageHeight`, `sideWidth`, `editorWidth`). Copy `Settings.qml` or `Themes.qml`.
- **A new view = this file + a `<X>OverlayView` schema definition + its `$ref` in `definitions.OverlayView.oneOf`.** The type const is the file name; pick one that doesn't collide with a content type (`CalendarPage`, not `Calendar`).
- **A tool page** (`x-tool: true`) is always in config: add it to the `Overlay.views` default, a `ConfigMigration` step that appends it to existing configs (copy `_v45ToV46` and its `tst_Config` test), a `_page(...)` entry in `services/LauncherCommands.qml`, and a row in the `docs/usage.md` launcher table.
- Editor pages follow `docs/dev/core/editors-pattern.md`: the manager owns the draft and selection (`select*()`), the page never assigns them.
- `settings/` holds hand-built settings parts: `x-card: "<Name>"` loads `settings/<Name>Card.qml` (titled by the section's `x-cardTitle`, never in its QML), `x-intro` loads `settings/<Name>.qml`. `check_structure.py` doesn't verify these exist: check yourself.
- A new subfolder imported only from URL-loaded files needs a qs restart (ask the user).
