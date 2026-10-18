# Layouts editor

> **Files:** `components/views/Layouts.qml`, `components/views/layouts/` (`LayoutsPanel`, `PagesSection`, `MenusSection`, `EditTarget`, `PageTarget`, `MenuTarget`, `ScreenLayoutTarget`, `DesktopTarget`, `LockscreenTarget`, `GreeterTarget`, `LayoutsEditorLayout`, `EditorInspector`), `components/hosts/overlay/OverlayPages.qml`, `services/OverlayManager.qml`, `config/OverlayConfig.qml`, `components/reusable/TypePickerPopup.qml`
> **Config:** `Overlay.views`, `EdgeMenus`, `Desktop`, `Lockscreen.layout`, `Greeter.layout`
> **Related:** [Grid canvas](grid-canvas.md), [Editors pattern](../core/editors-pattern.md), [Edge menu editing](../edge-menus/editing-submenus.md), [Desktop](../features/desktop.md), [Lockscreen](../features/lockscreen.md), [Greeter runtime](../features/greeter-runtime.md)

One page that edits overlay pages, edge menus, the desktop, the lock screen and the login screen. This doc covers the page itself, its edit targets and its left panel; the canvas, drag and `GridEditor` are in [Grid canvas](grid-canvas.md).

### The page
- `views/Layouts.qml`, with its pieces in `views/layouts/`.
- It's not in config: `OverlayPages` adds it (`pinnedPages`) as a persistent page after the Repeater, so it:
  - is always last;
  - can't be removed;
  - survives the page rebuild that every `Overlay.views` change causes. Pages are keyed by the views' JSON, so other config edits don't rebuild them; `_onPinned` keeps the user on it across that rebuild.

### Edit targets (`OverlayManager.editTarget`)
| Target | What it edits | Draft |
|---|---|---|
| `"page"` | `OverlayManager.selectedViewIndex` | its draft of `Overlay.views` |
| `"menu"` | `EdgeMenuManager.selectedMenuIndex` | its draft of `EdgeMenus` |
| `"desktop"` | `DesktopManager.editor` | its draft of `Desktop` |
| `"lockscreen"` | `LockManager.editor` | its draft of `Lockscreen.layout` |
| `"greeter"` | `GreeterManager.editor` | of `Greeter.layout` |

- Switched by `editPage(i)` / `editMenu(i)` / `editDesktop()` / `editLockscreen()` / `editGreeter()` / `editPages()` / `editMenus()`.
- The lock screen's row shows only while `Lockscreen.mode` is `quickshell` (`lockscreenEditable`), and the login screen's only while `Greeter.enabled` (`greeterEditable`).
- `editTarget` falls back to `"page"` when its row hides.
- Entry points: the launcher's `/layouts` and `/menus`, `ipc call edgeMenu edit`.
- Each target is an `EditTarget`: `PageTarget`, `MenuTarget`, and `DesktopTarget` / `LockscreenTarget` / `GreeterTarget` on `ScreenLayoutTarget` (all in `views/layouts/`). It carries the editor, modules, title, icon, screen box, fit line, …, and `Layouts.qml` binds the canvas and inspector to it.
- Save/Discard on the canvas save or discard all five drafts, and `EditsManager` lists the page as unsaved when any is dirty.

### Layout of the page
- `LayoutsPanel` on the left; on the right `GridCanvas` above `EditorInspector`, placed by `LayoutsEditorLayout`; a `GridDragLayer` covering it all.

### Left panel (`LayoutsPanel`)
- **`PagesSection`**:
  - Your pages, with show/hide, duplicate and remove actions, and New page under them.
  - Then the tool pages as a dimmed group with only show/hide. Every tool page is always in config (a migration put back any that were removed, hidden).
  - Each group is dragged to reorder within itself.
  - Then the Desktop, Lock screen and Login screen rows (not pages, not dragged).
- **`MenusSection`**: the edge menus, dragged to reorder, duplicate/remove, New menu.
- Then the selection's fields:
  - A page's name, icon and Double grid.
  - A tool page's Show in the navigator.
  - For any page, buttons adding a bar Button or keybind that opens it (`OverlayManager.addBarButton` / `addKeybind`). They use the `overlayPage` action on its `OverlayConfig.pageKey`: a Custom page's name, else its type. Only for a saved page, so an unnamed Custom page has none.
  - A menu's field groups (see [Edge menu editing](../edge-menus/editing-submenus.md)).
  - A screen layout's (`LayoutsPanel.screenTarget`):
    - the desktop's monitor picker and switches (see [Desktop](../features/desktop.md));
    - Show on screen (`canPreview`: not for a draft that already shows live, the desktop's);
    - field groups: the target's required `fieldGroups`, from its section's reader (`LockscreenConfig`, `GreeterConfig`, `DesktopConfig`);
    - "Can't save yet".

### Module and view pickers
- They read `OverlayConfig.availableModuleTypes` / `availableViewTypes` (`modulesFor(host)` for the `x-hosts` filter).
- These come from the schema's `oneOf`s, including `x-defaultSize`, `x-icon` and `x-tool`, so new types show up there automatically.
- `reusable/TypePickerPopup` is the shared "pick a type" popup, used by the bar editor (sorted by label) and the page list.
- Each bar widget and module joins one of the root's `x-libraryGroups` with `x-libraryGroup` (`group` on its type info; `check_structure.py` insists). The libraries' By category view groups by it (`OverlayConfig.libraryGroups`).
