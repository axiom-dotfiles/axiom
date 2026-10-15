# Settings page

> **Files:** `components/views/Settings.qml`, `components/methods/SchemaLayout.qml`, `components/views/settings/` (`SettingsGroupCard`, `EntryListCard`, `FoldingCard`, `SettingsSidebar`, `SettingsContent`), `components/forms/`, `services/SettingsManager.qml`
> **Config:** every section with settings (`x-settings` not false); fold state in `config/state/settings.json`
> **Related:** [Schema annotations](schema-annotations.md), [Editors pattern](editors-pattern.md), [Shared UI pieces](shared-ui-pieces.md)

How the schema becomes the settings page: layout, cards, folding, sidebar and search.

### From schema to rows
- `methods/SchemaLayout` turns the schema into categories → groups → rows.
- Only this page builds its own rows. Flat objects (array items, widget/module options, a bar's fields) render through `forms/SchemaPropertiesForm`.
- An `array` of objects renders as an add/remove/reorder list (`SchemaObjectArray`, items `SchemaArrayItem`).
- Text fields (`forms/SchemaTextField`) commit on Enter (Ctrl+Enter when multiline), on focus loss or teardown, and on a suggestion click or a folder picked with its Browse button (`x-control: "folder"`, [File picker](file-picker.md)), never per keystroke. Each commit re-applies the whole config live (~35 ms of JS before layout), and half-typed values had side effects: a font re-shaped every text, a notes folder ran `find` on `/`, `/home`, ….

### Cards
- Generated cards are `settings/SettingsGroupCard`.
- The Dock and OSD list cards are `EntryListCard`s:
  - entries as tabs
  - a screen picker with presets: by default an edge's middle or the bottom edge's ends, with `spotOf` reading `edge`/`position`
  - Show/Duplicate/Delete
  - the entry's form
  - `entryContent` for extras such as the dock's pinned apps.
- Both sit on `FoldingCard`: a fold header (section line, heading, unsaved dot, chevron, `headerExtras`) and a `FoldingColumn` body.
- Status cards (Hyprland, Idle, self-update, chat providers, onboarding) are `FieldGroup`s with a `StatusChip` in `headerExtras`.

### Folding
- Clicking a card's header folds it (`SettingsManager.collapsed`, by group key, saved to `config/state/settings.json`). Search results never fold.
- The masonry reads `layoutFolds`, a snapshot taken on category/search change and page unload, so a fold doesn't reshuffle the page.

### Sidebar and jumping
- The sidebar is `SettingsSidebar`: a `TitledCard` of `ListEntryRow`s, with search in its header.
- It lists the selected category's shown cards (`SettingsContent.shownGroups`, one per title) under its row.
  - They sit in a `FoldingColumn` that holds the links it opened with while it folds shut (by then `cardLinks` is the next category's).
- Clicking a card link calls `SettingsManager.jumpTo(key)`, which unfolds the card and emits `jumpRequested`.
  - The content scrolls to it (`TitledCard.scrollTo`, after the unfold animation) and outlines it in the accent for a moment.

### Transitions and search
- A new category, or entering/leaving search, fades the content in, sliding from the side of the sidebar it was picked from (`_pageIndex`).
- Search results are grouped by category (`blocks`): a heading with the category's icon, then its own two columns.

### Opening it from elsewhere
- Other services open the page on a section's category with `SettingsManager.openSection(key)`, so they don't depend on category names.
- A category has no IPC; for testing use a temporary `IpcHandler` (AGENTS.md › Running / reloading).
