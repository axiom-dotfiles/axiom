pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

import qs.config
import qs.components.methods

// Which edge menus (EdgeMenusConfig) are open and which are pinned. The
// menus themselves (shell/EdgeMenus) follow this and report back when they
// close on their own. Kept across QML reloads, so a reload doesn't close an
// integrated menu and reflow the windows. Pins are also saved to
// config/state/edgemenus.json, and a pinned menu opens again when qs starts.
//
// Also the layouts editor's working copy of EdgeMenus (the pinned Layouts
// overlay page), as BarManager is the bar editor's: edits
// show live on the running menus (ConfigManager.previews) until saved or
// reset, and `previewing` holds one menu open to try them on.
//
//   qs -c axiom ipc call edgeMenu toggle <id>
Singleton {
  id: root

  // { id: true } for each open / pinned menu
  readonly property var openMenus: root._parse(_run.open)
  readonly property var pinnedMenus: root._parse(_run.pinned)

  // What opened each menu (a bar button), which keeps a floating menu open
  // while hovered, as a bar popout's anchor does. Not kept across reloads.
  property var anchors: ({})

  // Space open integrated menus reserve, by "<screen>:<edge>" (edge
  // "top" | "bottom" | "left" | "right"), for surfaces that place
  // themselves against the perpendicular edges (BarPopouts)
  property var zones: ({})

  function setZone(screenName, edge, size) {
    const key = `${screenName}:${edge}`;
    if ((root.zones[key] ?? 0) === size)
      return;
    const zones = Object.assign({}, root.zones);
    if (size > 0)
      zones[key] = size;
    else
      delete zones[key];
    root.zones = zones;
  }

  function zoneOn(screenName, edge) {
    return root.zones[`${screenName}:${edge}`] ?? 0;
  }

  // Where each running menu's modules can sit on its screen, by id, as the
  // menu reports it (IntegratedEdgeMenu, FloatingEdgeMenu), for the
  // layouts editor. In px: { screen (its name), startPad, endPad (the
  // least room between the modules and the edge's ends), across (from the
  // screen edge to the modules), before (across, taken by what's on the
  // edge outside the menu: bars, the border), after (from the modules to
  // the menu's inner side), reserves (whether the menu reserves its strip) }
  property var frames: ({})

  function setFrame(id, frame) {
    if (!id || JSON.stringify(root.frames[id]) === JSON.stringify(frame))
      return;
    const frames = Object.assign({}, root.frames);
    frames[id] = frame;
    root.frames = frames;
  }

  function clearFrame(id, screenName) {
    if (root.frames[id]?.screen !== screenName)
      return;
    const frames = Object.assign({}, root.frames);
    delete frames[id];
    root.frames = frames;
  }

  // A menu's frame (see `frames`): its running one's, else (a disabled
  // menu, or one not yet reported) its padding all round
  function frameOf(menu) {
    const screenName = EdgeMenusConfig.screenFor(menu)?.name ?? "";
    const live = root.frames[menu?.id ?? ""];
    if (live && live.screen === screenName)
      return live;
    const pad = Appearance.borderWidth + EdgeMenusConfig.paddingOf(menu);
    return {
      "screen": screenName,
      "startPad": pad,
      "endPad": pad,
      "across": pad,
      "before": 0,
      "after": pad,
      "reserves": menu?.mode === "integrated"
    };
  }

  // Where a menu's modules sit on its screen, in px: { along (from the
  // edge's start), across (from the edge), length, depth (the modules'
  // grid along and across the edge), frame, screen }, or null without a
  // screen. Modules from `modules` when given (an edit's, before it).
  function placementOf(menu, modules) {
    const screen = EdgeMenusConfig.screenFor(menu);
    if (!menu || !screen)
      return null;
    const vertical = menu.edge === "Left" || menu.edge === "Right";
    const frame = root.frameOf(menu);
    const sizes = GridPlacement.trackSizes(GridPlacement.bounds(modules ?? menu.modules), root.cardUnitOf(menu));
    const length = vertical ? sizes.height : sizes.width;
    const edgeLength = vertical ? screen.height : screen.width;
    return {
      "along": EdgeMenusConfig.alongStartOf(menu, length, edgeLength, frame.startPad, frame.endPad),
      "across": frame.across,
      "length": length,
      "depth": vertical ? sizes.width : sizes.height,
      "edgeLength": edgeLength,
      "frame": frame,
      "screen": screen
    };
  }

  // A menu as it sits on its screen, in screen px: { name, rect (its box:
  // the modules plus the frame's `after` all round), modules: [{ type,
  // rect }] } (rects { x, y, width, height }), stretched along its edge
  // when it takes the whole edge. `index`: its place in the draft, for its
  // label.
  function screenRectsOf(menu, index) {
    const place = root.placementOf(menu);
    if (!place)
      return null;
    const vertical = menu.edge === "Left" || menu.edge === "Right";
    const room = place.edgeLength - place.frame.startPad - place.frame.endPad;
    const stretch = menu.length !== "edge" ? null : vertical ? {
      "height": room
    } : {
      "width": room
    };
    const sizes = GridPlacement.trackSizes(GridPlacement.bounds(menu.modules), root.cardUnitOf(menu), stretch);
    const depth = vertical ? sizes.width : sizes.height;
    const acrossAt = menu.edge === "Right" ? place.screen.width - place.across - depth : menu.edge === "Bottom" ? place.screen.height - place.across - depth : place.across;
    const x = vertical ? acrossAt : place.along;
    const y = vertical ? place.along : acrossAt;
    const pad = place.frame.after;
    return {
      "name": root.menuLabel(menu, index),
      "rect": {
        "x": x - pad,
        "y": y - pad,
        "width": sizes.width + pad * 2,
        "height": sizes.height + pad * 2
      },
      "modules": menu.modules.map(module => {
        const r = GridPlacement.rectPx(module.place, sizes);
        return {
          "type": module.type,
          "rect": {
            "x": x + r.x,
            "y": y + r.y,
            "width": r.width,
            "height": r.height
          }
        };
      })
    };
  }

  // After the editor's grid shifted by `shift` grid units ({ x, y }; a
  // module put before the first moves the menu that way), keeps the
  // selected menu's modules where they were on its screen: its anchor
  // (align, offset) follows, snapping to an end or the middle within half
  // a unit of it (GridPlacement.anchorFor). `before`: its modules before
  // the edit.
  function _followShift(menu, shift, before) {
    if (!menu || menu.length === "edge")
      return;
    const was = root.placementOf(menu, before);
    const now = root.placementOf(menu);
    if (!was || !now)
      return;
    const vertical = menu.edge === "Left" || menu.edge === "Right";
    const start = was.along + (vertical ? shift.y : shift.x) * GridPlacement.stepOf(root.cardUnitOf(menu));
    const anchor = GridPlacement.anchorFor(start, now.length, now.edgeLength, root.cardUnitOf(menu), now.frame.startPad, now.frame.endPad, menu.align, menu.offset);
    menu.align = anchor.align;
    menu.offset = anchor.offset;
  }

  // The editor draws the other menus on the selected one's screen
  property bool showingOthers: false

  function toggleShowingOthers() {
    root.showingOthers = !root.showingOthers;
  }

  PersistentProperties {
    id: _run
    reloadableId: "axiomEdgeMenus"
    // JSON lists of ids
    property string open: "[]"
    property string pinned: "[]"
    // False only on the first load after qs starts
    property bool started: false

    onLoaded: {
      if (_run.started)
        return;
      _run.started = true;
      const pinned = root._state.load({}).pinned;
      if (!Array.isArray(pinned))
        return;
      const ids = pinned.filter(id => EdgeMenusConfig.menuById(id));
      _run.pinned = JSON.stringify(ids);
      _run.open = JSON.stringify(ids);
    }
  }

  readonly property var _state: StateManager.createStateHandler("edgemenus")

  function _parse(json) {
    try {
      return JSON.parse(json).reduce((map, id) => {
        map[id] = true;
        return map;
      }, {});
    } catch (e) {
      return {};
    }
  }

  function _set(map, id, on) {
    const ids = Object.keys(map).filter(key => key !== id);
    if (on)
      ids.push(id);
    return JSON.stringify(ids);
  }

  // True for a menu held open by the editor: it ignores closeOnLeave and
  // outside clicks, as a pinned one does
  function isHeld(id) {
    return root.isPinned(id) || (id !== "" && root.previewing === id);
  }

  function isOpen(id) {
    return root.openMenus[id] === true;
  }
  function isPinned(id) {
    return root.pinnedMenus[id] === true;
  }

  // A module's host (Card/Panel.host) is an edge menu it can pin
  function canPin(host) {
    return host?.kind === "edgeMenu" && !!host.id;
  }

  function _exists(id) {
    if (EdgeMenusConfig.menuById(id))
      return true;
    console.warn("[EdgeMenuManager] No edge menu with id", id);
    return false;
  }

  function open(id, anchor) {
    if (!root._exists(id))
      return;
    const anchors = Object.assign({}, root.anchors);
    anchors[id] = anchor ?? null;
    root.anchors = anchors;
    _run.open = root._set(root.openMenus, id, true);
  }

  // Menus opened for something outside them (the launcher, IPC) that take
  // the cursor: the menu warps it into its box once shown
  // (HyprlandManager.warpCursorToLayer), and doesn't close on leave until
  // it has been hovered. Not kept across reloads.
  property var revealing: ({})

  // Opens a menu and moves the cursor into it, so one that closes when the
  // pointer leaves stays open
  function reveal(id) {
    if (!root._exists(id))
      return;
    root.revealing = root._parse(root._set(root.revealing, id, true));
    root.open(id, null);
  }

  // The menu was hovered, or closed
  function revealDone(id) {
    if (root.revealing[id] === true)
      root.revealing = root._parse(root._set(root.revealing, id, false));
  }

  function close(id) {
    if (!root.isOpen(id))
      return;
    _run.open = root._set(root.openMenus, id, false);
  }

  function toggle(id, anchor) {
    if (root.isOpen(id))
      root.close(id);
    else
      root.open(id, anchor);
  }

  function setPinned(id, pinned) {
    _run.pinned = root._set(root.pinnedMenus, id, pinned);
    root._state.save({
      "pinned": JSON.parse(_run.pinned)
    });
  }

  function togglePinned(id) {
    root.setPinned(id, !root.isPinned(id));
  }

  // --- Editor ---

  property ConfigDraft _draft: ConfigDraft {
    id: draft
    path: ["EdgeMenus"]
  }
  readonly property alias localMenus: draft.local
  readonly property alias savedMenus: draft.saved
  readonly property alias isDirty: draft.isDirty
  property int selectedMenuIndex: 0

  // The selected menu's modules (see GridEditor)
  property GridEditor layout: GridEditor {
    host: "edgeMenu"
    modulesOf: () => root.selectedMenu()?.modules ?? null
    shifted: (shift, before) => root._followShift(root.selectedMenu(), shift, before)
    scopeKey: String(root.selectedMenuIndex)
    onEdited: root.applyChanges()
  }

  // The menu the editor holds open to try edits on ("" for none)
  property string previewing: ""

  // Why the draft can't be saved as is (empty = savable)
  readonly property var problems: {
    const out = [];
    const menus = root.localMenus ?? [];
    menus.forEach((menu, m) => {
      const name = root.menuLabel(menu, m);
      if (!menu.id)
        out.push(I18n.tr("{0} has no id", name));
      else if (menus.findIndex(other => other.id === menu.id) !== m)
        out.push(I18n.tr("{0}: another menu has the id {1}", name, menu.id));
      out.push(...root.layout.problemsFor(menu.modules, name));
    });
    return out;
  }

  function menuLabel(menu, index) {
    return menu?.name || menu?.id || I18n.tr("Menu {0}", index + 1);
  }

  // Keeps the selected menu where it still exists
  function loadConfig() {
    draft.load();
    ConfigManager.clearPreview("EdgeMenus");
    root.selectedMenuIndex = Math.max(0, Math.min(root.selectedMenuIndex, (root.localMenus?.length ?? 1) - 1));
    root.layout.clearSelection();
    root._followPreview();
  }

  // Loads the draft unless it holds unsaved edits (the page is rebuilt
  // whenever the overlay reopens)
  function ensureLoaded() {
    if (!draft.isDirty)
      root.loadConfig();
  }

  // Call after mutating localMenus in place: shows the edit on the running
  // menus while the draft differs from the saved config
  function applyChanges() {
    draft.changed();
    if (draft.isDirty)
      ConfigManager.setPreview("EdgeMenus", draft.local);
    else
      ConfigManager.clearPreview("EdgeMenus");
  }

  // Whether a menu differs from its saved version (matched by id)
  function menuChanged(index) {
    const menu = root.localMenus?.[index];
    const saved = (root.savedMenus ?? []).find(m => m.id === menu?.id);
    return JSON.stringify(menu) !== JSON.stringify(saved);
  }

  // A menu's card size: its screen's overlay's (OverlayManager.areas, or
  // what the overlay would take on that screen before it reports one),
  // scaled by the menu's moduleScale
  function cardUnitOf(menu) {
    const screen = EdgeMenusConfig.screenFor(menu);
    const area = OverlayManager.areas[screen?.name ?? ""];
    const unit = area ? area.unit : screen ? OverlayConfig.cardUnitFor(screen.width, screen.height) : OverlayConfig.cardUnit;
    return Math.round(unit * menu.moduleScale / 100);
  }

  function selectedMenu() {
    return root.localMenus?.[root.selectedMenuIndex] || null;
  }

  function selectMenu(index) {
    if (index === root.selectedMenuIndex)
      return;
    root.selectedMenuIndex = index;
    root.layout.clearSelection();
    root._followPreview();
  }

  function _uniqueId(base) {
    const taken = (root.localMenus ?? []).map(menu => menu.id);
    let n = 1;
    while (taken.includes(`${base}-${n}`))
      n++;
    return `${base}-${n}`;
  }

  // A new menu at the schema defaults, opening on hover, and held open on
  // screen so edits show as they're made
  function addMenu() {
    const id = root._uniqueId("menu");
    const menu = ConfigManager.withDefaults({
      "id": id,
      "name": I18n.tr("Menu {0}", id.split("-").pop()),
      "openOnHover": true,
      "modules": []
    }, "EdgeMenu");
    root.localMenus.push(menu);
    root.applyChanges();
    root.selectMenu(root.localMenus.length - 1);
    root.startPreviewing();
  }

  function duplicateMenu(index) {
    const menu = root.localMenus?.[index];
    if (!menu)
      return;
    const copy = Utils.clone(menu);
    copy.id = root._uniqueId(menu.id || "menu");
    if (copy.name)
      copy.name = I18n.tr("{0} (copy)", copy.name);
    root.localMenus.splice(index + 1, 0, copy);
    root.applyChanges();
    root.selectMenu(index + 1);
  }

  // The selected menu stays selected wherever it ends up
  function moveMenu(from, to) {
    const selected = root.selectedMenu();
    if (GridPlacement.moveTo(root.localMenus, from, to) < 0)
      return;
    root.selectedMenuIndex = Math.max(0, root.localMenus.indexOf(selected));
    root.applyChanges();
  }

  function removeMenu(index) {
    const menu = root.localMenus?.[index];
    if (!menu)
      return;
    if (root.previewing === menu.id)
      root._showPreview("");
    root.localMenus.splice(index, 1);
    root.selectedMenuIndex = Math.max(0, Math.min(root.selectedMenuIndex, root.localMenus.length - 1));
    root.layout.clearSelection();
    root.applyChanges();
    root._followPreview();
  }

  // One of the selected menu's own fields (not its columns)
  function updateMenuField(key, value) {
    const menu = root.selectedMenu();
    if (!menu || JSON.stringify(menu[key]) === JSON.stringify(value))
      return;
    const wasPreviewing = root.previewing !== "" && root.previewing === menu.id;
    if (wasPreviewing && key === "id")
      root._showPreview("");
    menu[key] = value;
    root.applyChanges();
    // A renamed (or re-enabled) menu is a new window: open that one
    if (wasPreviewing || (root._wantPreview && key === "enabled"))
      Qt.callLater(root._followPreview);
  }

  // --- How a menu opens ---

  // What opens menu `id` besides hovering its edge: bar Buttons (in the
  // bar editor's draft) and keybinds (in the keybind editor's).
  // [{ kind: "bar" | "bind", label }]
  function references(id) {
    if (!id)
      return [];
    const out = [];
    (BarManager.localConfig ?? Bar.savedBars).forEach((bar, b) => Object.keys(bar?.widgets ?? {}).forEach(zone => (bar.widgets[zone] ?? []).forEach(widget => {
          if (widget?.type === "Button" && widget.properties?.action === "edgeMenu" && widget.properties?.menu === id)
            out.push({
              "kind": "bar",
              "label": I18n.tr("Button on {0}", bar.id || I18n.tr("Bar {0}", b + 1))
            });
        })));
    (KeybindManager.isDirty ? KeybindManager.binds : HyprlandConfig.binds).forEach(bind => {
      if (bind?.action === "edgeMenu" && bind.argument === id)
        out.push({
          "kind": "bind",
          "label": bind.key ? I18n.tr("Keybind {0}", KeybindManager.displayKey(bind.key)) : I18n.tr("Keybind (no key yet)")
        });
    });
    return out;
  }

  // Adds a Button that toggles the selected menu to bar `barIndex`'s
  // `zone`, in the bar editor's draft (saved from there or with Save all)
  function addBarButton(barIndex, zone) {
    const menu = root.selectedMenu();
    if (!menu?.id)
      return;
    BarManager.addWidgetTo(barIndex, zone, {
      "type": "Button",
      "properties": {
        "action": "edgeMenu",
        "menu": menu.id,
        "icon": Utils.edgeArrow(menu.edge),
        "tooltip": menu.name || menu.id
      }
    });
  }

  // Adds a keybind that toggles the selected menu, then opens the keybinds
  // page recording its key
  function addKeybind() {
    const menu = root.selectedMenu();
    if (!menu?.id)
      return;
    KeybindManager.ensureLoaded();
    KeybindManager.addBind({
      "action": "edgeMenu",
      "argument": menu.id,
      "call": "toggle"
    }, true);
    ShellManager.openOverlayPage("Keybinds");
    Qt.callLater(() => KeybindManager.startRecording(0));
  }

  // --- Trying a menu out ---

  // Whether the editor wants the selected menu held open; stays set while
  // switching menus, so the preview follows the selection
  property bool _wantPreview: false

  function canPreview(menu) {
    return !!menu?.id && menu.enabled !== false;
  }

  function startPreviewing() {
    root._wantPreview = true;
    root._followPreview();
  }

  function stopPreviewing() {
    root._wantPreview = false;
    root._showPreview("");
  }

  function togglePreviewing() {
    if (root._wantPreview)
      root.stopPreviewing();
    else
      root.startPreviewing();
  }

  function _followPreview() {
    if (!root._wantPreview)
      return;
    const menu = root.selectedMenu();
    root._showPreview(root.canPreview(menu) ? menu.id : "");
  }

  function _showPreview(id) {
    if (root.previewing === id)
      return;
    if (root.previewing !== "")
      root.close(root.previewing);
    root.previewing = id;
    // After the preview reaches EdgeMenusConfig, so a new menu exists
    if (id !== "")
      Qt.callLater(() => {
        if (root.previewing === id)
          root.open(id, null);
      });
  }

  function saveChanges() {
    if (root.problems.length > 0)
      return false;
    if (!draft.save())
      return false;
    ConfigManager.clearPreview("EdgeMenus");
    return true;
  }

  function resetChanges() {
    root.loadConfig();
  }

  property IpcHandler _ipc: IpcHandler {
    target: "edgeMenu"

    function open(id: string): void {
      root.open(id, null);
    }

    function close(id: string): void {
      root.close(id);
    }

    function toggle(id: string): void {
      root.toggle(id, null);
    }

    function pin(id: string): void {
      root.setPinned(id, true);
    }

    function unpin(id: string): void {
      root.setPinned(id, false);
    }

    // Opens the layouts editor on the edge menus
    function edit(): void {
      OverlayManager.editMenus();
      ShellManager.openOverlayPage("Layouts");
    }

    function list(): string {
      return EdgeMenusConfig.menus.map(menu => `${menu.id}${root.isOpen(menu.id) ? " (open)" : ""}${root.isPinned(menu.id) ? " (pinned)" : ""}`).join("\n");
    }
  }
}
