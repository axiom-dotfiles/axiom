pragma Singleton
import QtQuick

import qs.components.methods

/* BarManager holds the bar editor's working copy of the Bars config. Edits
 * show live on the running bars (through ConfigManager.previews) as
 * they're made; saveChanges() writes them to config.json, resetChanges()
 * drops them. The preview is never part of ConfigManager.config, so other
 * saves (a theme, the settings page) don't persist unsaved bar edits.
 *
 * Also keeps the page's own state (selected bar and widget), since the
 * page is unloaded whenever the overlay closes. */
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

  readonly property var zones: ["left", "leftCenter", "center", "rightCenter", "right"]

  onSelectedBarIndexChanged: clearSelection()

  // Keeps the selected bar and widget where they still exist
  function loadConfig() {
    draft.load();
    ConfigManager.clearPreview("Bars");
    selectedBarIndex = Math.max(0, Math.min(selectedBarIndex, (root.localConfig?.length ?? 1) - 1));
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

  function _clone(value) {
    return JSON.parse(JSON.stringify(value ?? null));
  }

  // --- Bars ---

  function addBar() {
    // Every other field comes from the Bar schema's defaults
    const bar = SchemaValidation.applyDefaults({
      "id": "bar-" + (root.localConfig.length + 1)
    }, {
      "$ref": "#/definitions/Bar"
    }, ConfigManager.configSchema);
    root.localConfig.push(bar);
    root.selectedBarIndex = root.localConfig.length - 1;
    applyChanges();
  }

  function removeBar(index) {
    if (root.localConfig.length <= 1)
      return; // never remove the last bar
    root.localConfig.splice(index, 1);
    root.selectedBarIndex = Math.max(0, Math.min(root.selectedBarIndex, root.localConfig.length - 1));
    clearSelection();
    applyChanges();
  }

  // The first bar is the primary one: move the chosen bar to the front
  function setPrimary(index) {
    if (index <= 0 || index >= root.localConfig.length)
      return;
    const [bar] = root.localConfig.splice(index, 1);
    root.localConfig.unshift(bar);
    root.selectedBarIndex = 0;
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
  }

  function clearSelection() {
    selectWidget("", -1);
  }

  function isSelected(zone, index) {
    return root.selectedWidget.zone === zone && root.selectedWidget.index === index;
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
    arr.splice(at, 0, SchemaValidation.applyDefaults({
      "type": widgetType
    }, {
      "$ref": "#/definitions/BarWidget"
    }, ConfigManager.configSchema));
    selectWidget(zone, at);
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
    arr.splice(index + 1, 0, _clone(arr[index]));
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
}
