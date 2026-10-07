pragma Singleton
import QtQuick
import Quickshell
import qs.config
import qs.components.methods

/* BarManager holds the bar editor's working copy of the Bars config. Edits
 * show live on the running bars (through ConfigManager.previews) as
 * they're made; saveChanges() writes them to config.json, resetChanges()
 * drops them. The preview is never part of ConfigManager.config, so other
 * saves (a theme, the settings page) don't persist unsaved bar edits.
 *
 * Also keeps the page's own state (selected bar and widget), since the
 * page is unloaded whenever the overlay closes, and, while the page is on
 * screen, what the running bars report back about the selected bar.
 *
 * And the running bars themselves (`bars`), laid out with Hyprland's gaps
 * (Bar.enrichBarConfig), with what they leave on each screen edge: which
 * bar is there, where windows start, where surfaces held off it measure
 * from. */
QtObject {
  id: root

  property ConfigDraft _draft: ConfigDraft {
    id: draft
    path: ["Bars"]
  }
  readonly property alias localConfig: draft.local
  readonly property alias savedConfig: draft.saved
  readonly property alias isDirty: draft.isDirty
  property int selectedBarIndex: 0
  // The widget open in the inspector: { zone, index }, zone "" for none
  property var selectedWidget: ({
      "zone": "",
      "index": -1
    })
  // The section last selected or added to, where the library adds
  property string lastZone: "center"

  // A bar's look: the fields in its look groups (`x-group`), not its
  // identity, placement, behaviour or widgets
  readonly property var styleGroups: ["Size", "Style", "Widgets", "Accents", "Shadow"]
  readonly property var styleKeys: [].concat(...Bar.fieldGroups.filter(group => root.styleGroups.includes(group.title)).map(group => group.keys))
  // The style copied with copyStyle(): { index, values }, or null. By
  // index, since ids may be empty or shared: kept pointing at its bar as
  // bars are added, moved and removed. Never saved.
  property var copiedStyle: null

  // The bar editor pages on screen (`watch`/`unwatch`). While there are
  // any, the running bars outline the selected widget and report to `live`
  property ConsumerRegistry _watchers: ConsumerRegistry {}
  readonly property bool editing: root._watchers.active
  // What each running bar reports while editing, by its id (a bar on every
  // monitor has one per screen): { source (its config entry's id), screen,
  // hidden: { zone: [widget indices hidden for want of room] }, selected:
  // how it sizes the selected widget ({ policy, size, preferred, minimum,
  // priority }), or null }
  readonly property var live: root._live
  property var _live: ({})

  function watch(owner) {
    root._watchers.acquire(owner, true);
  }

  function unwatch(owner) {
    root._watchers.release(owner);
  }

  function setLive(id, report) {
    if (id && JSON.stringify(root._live[id]) !== JSON.stringify(report))
      root._live = Utils.withEntry(root._live, id, report ?? undefined);
  }

  // Clears a bar's report, unless another bar (on another screen) has
  // taken its id since
  function clearLive(id, screenName) {
    if (root._live[id]?.screen === screenName)
      root._live = Utils.withEntry(root._live, id, undefined);
  }

  // The selected bar's reports, one per screen it's on, by screen name
  function liveReports() {
    const id = selectedBar()?.id;
    return Object.values(root.live).filter(report => report.source === id).sort((a, b) => a.screen.localeCompare(b.screen));
  }

  // Whether a running bar (by its config entry's id) shows the selected
  // widget, while editing
  function isSelectedWidget(source, zone, index) {
    const sel = root.selectedWidget;
    return root.editing && sel.zone === zone && sel.index === index && selectedBar()?.id === source;
  }

  onSelectedBarIndexChanged: clearSelection()

  function selectBar(index) {
    root.selectedBarIndex = index;
  }

  // Keeps the selected bar and widget where they still exist
  function loadConfig() {
    draft.load();
    ConfigManager.clearPreview("Bars");
    selectedBarIndex = Math.max(0, Math.min(selectedBarIndex, (root.localConfig?.length ?? 1) - 1));
    if (root.copiedStyle && root.copiedStyle.index >= (root.localConfig?.length ?? 0))
      root.copiedStyle = null;
    if (!selectedWidgetConfig())
      clearSelection();
  }

  // Loads the draft unless it holds unsaved edits (the page is rebuilt
  // whenever the overlay reopens)
  function ensureLoaded() {
    if (!draft.isDirty)
      loadConfig();
  }

  // Call after mutating localConfig in place: shows the edit on the
  // running bars while the draft differs from the saved config
  function applyChanges() {
    draft.changed();
    if (draft.isDirty)
      ConfigManager.setPreview("Bars", draft.local);
    else
      ConfigManager.clearPreview("Bars");
  }

  // Whether a bar differs from its saved version (matched by id)
  function barChanged(index) {
    const bar = root.localConfig?.[index];
    const saved = (root.savedConfig ?? []).find(b => b.id === bar?.id);
    return JSON.stringify(bar) !== JSON.stringify(saved);
  }

  function selectedBar() {
    return root.localConfig?.[root.selectedBarIndex] || null;
  }

  function _zone(zone) {
    const bar = selectedBar();
    if (!bar)
      return null;
    if (!bar.widgets)
      bar.widgets = {};
    if (!bar.widgets[zone])
      bar.widgets[zone] = [];
    return bar.widgets[zone];
  }

  // --- Bars ---

  function addBar() {
    // Every other field comes from the Bar schema's defaults
    const bar = ConfigManager.withDefaults({
      "id": _uniqueId("bar-" + (root.localConfig.length + 1))
    }, "Bar");
    root.localConfig.push(bar);
    root.selectedBarIndex = root.localConfig.length - 1;
    applyChanges();
  }

  // An id no bar in the draft has: `base`, else `base-2`, `base-3`, ...
  function _uniqueId(base) {
    return Utils.freeId(base, root.localConfig.map(b => b.id), "-");
  }

  // Inserts a copy after the bar and selects it. A copy of a bar on one
  // monitor moves to the first screen with no bar on that edge yet, so it
  // doesn't sit on the original.
  function duplicateBar(index) {
    const bar = root.localConfig?.[index];
    if (!bar)
      return;
    const copy = Utils.clone(bar);
    copy.id = _uniqueId(`${bar.id}-copy`);
    if (bar.monitor !== "*") {
      const onEdge = root.localConfig.filter(b => b.location === bar.location).map(b => b.monitor === "*" ? "*" : General.screensNamed(b.monitor)[0]?.name ?? "");
      const free = Quickshell.screens.find(s => !onEdge.includes(s.name) && !onEdge.includes("*"));
      if (free)
        copy.monitor = free.name;
    }
    root.localConfig.splice(index + 1, 0, copy);
    _moveCopied(i => i > index ? i + 1 : i);
    root.selectedBarIndex = index + 1;
    applyChanges();
  }

  // The name a bar is listed by: its id, else its place
  function barLabel(index) {
    return root.localConfig?.[index]?.id || I18n.tr("Bar {0}", index + 1);
  }

  // Follows the copied style's bar to its new index (-1: it's gone)
  function _moveCopied(map) {
    if (!root.copiedStyle)
      return;
    const index = map(root.copiedStyle.index);
    root.copiedStyle = index < 0 ? null : {
      "index": index,
      "values": root.copiedStyle.values
    };
  }

  function copyStyle(index) {
    const bar = root.localConfig?.[index];
    if (!bar)
      return;
    root.copiedStyle = {
      "index": index,
      "values": Utils.clone(root.styleKeys.reduce((out, key) => {
        if (key in bar)
          out[key] = bar[key];
        return out;
      }, {}))
    };
  }

  function _pasteStyleOnto(bar) {
    Object.assign(bar, Utils.clone(root.copiedStyle.values));
  }

  function pasteStyle(index) {
    const bar = root.localConfig?.[index];
    if (!bar || !root.copiedStyle)
      return;
    _pasteStyleOnto(bar);
    applyChanges();
  }

  function pasteStyleToAll() {
    if (!root.copiedStyle)
      return;
    root.localConfig.forEach(bar => _pasteStyleOnto(bar));
    applyChanges();
  }

  function removeBar(index) {
    if (root.localConfig.length <= 1)
      return; // never remove the last bar
    root.localConfig.splice(index, 1);
    _moveCopied(i => i === index ? -1 : i > index ? i - 1 : i);
    root.selectedBarIndex = Math.max(0, Math.min(root.selectedBarIndex, root.localConfig.length - 1));
    clearSelection();
    applyChanges();
  }

  function updateBarField(key, value) {
    const bar = selectedBar();
    if (!bar)
      return;
    bar[key] = value;
    applyChanges();
  }

  // --- Widgets ---

  function selectWidget(zone, index) {
    root.selectedWidget = {
      "zone": zone,
      "index": index
    };
    if (zone !== "")
      root.lastZone = zone;
  }

  function clearSelection() {
    selectWidget("", -1);
  }

  function selectedWidgetConfig() {
    const sel = root.selectedWidget;
    return sel.zone === "" ? null : (selectedBar()?.widgets?.[sel.zone]?.[sel.index] ?? null);
  }

  // Inserts a new widget at `index` (the end by default) and selects it
  function addWidget(zone, widgetType, index = -1) {
    const arr = _zone(zone);
    if (!arr)
      return;
    const at = index < 0 || index > arr.length ? arr.length : index;
    // Properties start at the widget schema's defaults
    arr.splice(at, 0, ConfigManager.withDefaults({
      "type": widgetType
    }, "BarWidget"));
    selectWidget(zone, at);
    applyChanges();
  }

  // Appends `widget` ({ type, properties }, the rest from the schema's
  // defaults) to bar `barIndex`'s `zone` and selects that bar and widget;
  // for other editors (an edge menu's "Add to a bar")
  function addWidgetTo(barIndex, zone, widget) {
    ensureLoaded();
    const bar = root.localConfig?.[barIndex];
    if (!bar)
      return;
    if (!bar.widgets)
      bar.widgets = {};
    if (!bar.widgets[zone])
      bar.widgets[zone] = [];
    bar.widgets[zone].push(ConfigManager.withDefaults(widget, "BarWidget"));
    selectBar(barIndex);
    selectWidget(zone, bar.widgets[zone].length - 1);
    applyChanges();
  }

  function removeWidget(zone, index) {
    const arr = selectedBar()?.widgets?.[zone];
    if (!arr || index < 0 || index >= arr.length)
      return;
    arr.splice(index, 1);
    const sel = root.selectedWidget;
    if (sel.zone === zone) {
      if (sel.index === index)
        clearSelection();
      else if (sel.index > index)
        selectWidget(zone, sel.index - 1);
    }
    applyChanges();
  }

  function duplicateWidget(zone, index) {
    const arr = selectedBar()?.widgets?.[zone];
    if (!arr?.[index])
      return;
    arr.splice(index + 1, 0, Utils.clone(arr[index]));
    selectWidget(zone, index + 1);
    applyChanges();
  }

  // Moves a widget to `toIndex` in `toZone`, counted as if it were still in
  // place (so dropping it just after itself leaves it where it is). The
  // selection follows whatever moved.
  function moveWidget(fromZone, fromIndex, toZone, toIndex) {
    const from = selectedBar()?.widgets?.[fromZone];
    const to = _zone(toZone);
    if (!from || !to || fromIndex < 0 || fromIndex >= from.length)
      return;
    let at = Math.max(0, Math.min(toIndex, to.length));
    if (fromZone === toZone && at > fromIndex)
      at--;
    if (fromZone === toZone && at === fromIndex)
      return;

    const sel = root.selectedWidget;
    const [item] = from.splice(fromIndex, 1);
    to.splice(at, 0, item);

    if (sel.zone === fromZone && sel.index === fromIndex) {
      selectWidget(toZone, at);
    } else if (sel.zone !== "") {
      // Shift a selection the move went past
      let index = sel.index;
      if (sel.zone === fromZone && index > fromIndex)
        index--;
      if (sel.zone === toZone && index >= at)
        index++;
      if (index !== sel.index)
        selectWidget(sel.zone, index);
    }
    applyChanges();
  }

  function _widget(zone, index) {
    return selectedBar()?.widgets?.[zone]?.[index] ?? null;
  }

  function updateWidgetProperty(zone, index, key, value) {
    const widget = _widget(zone, index);
    if (!widget)
      return;
    if (!widget.properties)
      widget.properties = {};
    widget.properties[key] = value;
    applyChanges();
  }

  function setWidgetVisible(zone, index, visible) {
    const widget = _widget(zone, index);
    if (!widget)
      return;
    if (visible)
      delete widget.visible;
    else
      widget.visible = false;
    applyChanges();
  }

  // Layout overrides are optional: an empty value removes the override
  function updateWidgetLayout(zone, index, key, value) {
    const widget = _widget(zone, index);
    if (!widget)
      return;
    const layout = Object.assign({}, widget.layout ?? {});
    if (value === undefined || value === null || value === "")
      delete layout[key];
    else
      layout[key] = value;
    if (Object.keys(layout).length > 0)
      widget.layout = layout;
    else
      delete widget.layout;
    applyChanges();
  }

  // Merged onto the latest real config; stays dirty if rejected
  function saveChanges() {
    if (!draft.save())
      return false;
    ConfigManager.clearPreview("Bars");
    return true;
  }

  // Discard edits: reload from the current config, and the bars with it
  function resetChanges() {
    loadConfig();
  }

  // The running bars: while the bar editor has unsaved edits, those
  readonly property var bars: Bar.expandBars(ConfigManager.previews.Bars ?? ConfigManager.config.Bars).map(bar => Bar.enrichBarConfig(bar, HyprlandManager.gapsOut))

  // The enabled bars on a screen by edge ({ top, bottom, left, right },
  // null where there is none)
  function edgesFor(screen) {
    const edges = {
      "top": null,
      "bottom": null,
      "left": null,
      "right": null
    };
    root.bars.forEach(bar => {
      if (!bar.enabled || bar.monitor !== screen?.name)
        return;
      const edge = bar.top ? "top" : bar.bottom ? "bottom" : bar.left ? "left" : "right";
      if (!edges[edge])
        edges[edge] = bar;
    });
    return edges;
  }

  // Whether a screen edge (a Bar.Location) is bare: no screen border and no
  // bar on it, so surfaces there run straight off the screen
  function screenEdgeOpen(screen, location) {
    if (Appearance.screenBorder)
      return false;
    return !root.edgesFor(screen)[Bar.edgeName(location)];
  }

  // Where windows start on a screen edge (a Bar.Location), in px from it:
  // the border's and bar's reserved space, Hyprland's gaps_out not
  // included, nor integrated edge menus' zones (EdgeMenuManager.reservedOn
  // adds those)
  function reservedOn(screen, location) {
    const bar = root.edgesFor(screen)[Bar.edgeName(location)];
    const zone = bar ? Bar.reservedZone(bar, HyprlandManager.gapsOut[Bar.edgeName(location)]) : 0;
    return (Appearance.screenBorder ? Appearance.screenMargin : 0) + zone - (zone > 0 && bar.insideBorder ? Appearance.borderWidth : 0);
  }

  // The inner side of what's on a screen edge, in px from it: the
  // border's stroke, or the bar there (a solid bar's inner stroke, a
  // floating bar's islands, a pill bar's far side, a transparent bar's
  // inner edge); 0 on a bare edge. Surfaces held off an edge measure their
  // gap from it (detachedGaps). Integrated edge menus' zones not included
  // (EdgeMenuManager.frameLineOn adds those).
  function frameLine(screen, location) {
    const bar = root.edgesFor(screen)[Bar.edgeName(location)];
    const margin = Appearance.screenBorder ? Appearance.screenMargin : 0;
    if (!bar)
      return margin;
    // Its outer edge on the border's stroke
    if (bar.insideBorder)
      return margin - Appearance.borderWidth + bar.extent;
    // The border's strip, laid over its inner part, draws its stroke
    if (bar.solid && Appearance.screenBorder)
      return bar.reserveSpace ? bar.extent + Appearance.borderWidth : margin;
    return bar.extent;
  }

  // The gaps a surface held off a screen edge (a Bar.Location) keeps from
  // the frame lines (frameLine) across that edge and at its two ends (the
  // perpendicular edges at its start and end: top and bottom, or left and
  // right): `gap` on each when it's 0 or more. Automatic (-1), it lines up
  // with a floating bar on that edge, its float gap on all three, else
  // with the windows: how far past each frame line they start.
  function detachedGaps(screen, location, gap) {
    if (gap >= 0)
      return {
        "across": gap,
        "start": gap,
        "end": gap
      };
    const bar = root.edgesFor(screen)[Bar.edgeName(location)];
    const windowGap = side => bar?.island ? bar.floatGap : Math.max(0, root.reservedOn(screen, side) + HyprlandManager.gapsOut[Bar.edgeName(side)] - root.frameLine(screen, side));
    const vertical = location === Bar.Left || location === Bar.Right;
    return {
      "across": windowGap(location),
      "start": windowGap(vertical ? Bar.Top : Bar.Left),
      "end": windowGap(vertical ? Bar.Bottom : Bar.Right)
    };
  }
}
