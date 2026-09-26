pragma ComponentBehavior: Bound

import QtQuick

// One bar section: a row (or column, on a vertical bar) of BarWidgetHosts that
// fits itself into `maxExtent` along the main axis by shrinking elastic
// modules. Which modules to drop when the whole bar overflows is decided
// bar-wide by BarContainer (`hiddenIndices`); should the minimum sizes
// still not fit, the lowest-priority modules here are hidden as a last
// resort. Sizes are measured from the modules and never from the
// allocation, so this can't feed back into itself.
Item {
  id: root

  required property var barConfig
  property var popouts
  property var panel
  property var screen
  // The section's widgets (BarContainer.widgetModel entries). Modelled by
  // count, so edits to a widget's options reach it in place instead of
  // rebuilding every widget in the section.
  property var widgets: []

  property int spacing: root.barConfig.spacing
  // Room the bar's section layout gives this group along the main axis
  property real maxExtent: Infinity
  // Which way the group grows within its slot (0 start, 1 end, 0.5 center)
  property real align: 0.5
  // Model indices the bar has hidden to make everything fit
  property var hiddenIndices: []

  readonly property bool isVertical: barConfig.vertical

  property var _modules: []

  readonly property var measures: root._modules.map(m => ({
        "pref": m.preferredSize,
        "min": m.minimumSize,
        "priority": m.priority
      }))
  readonly property var _shown: root.measures.map((m, i) => m.pref > 0 && !root.hiddenIndices.includes(i))

  // Main-axis size wanted with every shown module at its preferred size,
  // and the least it can be squeezed to without hiding anything more
  readonly property real preferredLength: root._span(root.measures.map((m, i) => root._shown[i] ? m.pref : 0))
  readonly property real minimumLength: root._span(root.measures.map((m, i) => root._shown[i] ? m.min : 0))

  readonly property var allocation: root.allocate(root.measures, root._shown, root.maxExtent, root.spacing)
  readonly property real usedLength: root._span(root.allocation.sizes)

  // Emitted when modules moved or resized within the group
  signal allocationUpdated
  property string _allocationKey: ""
  onAllocationChanged: {
    const key = JSON.stringify(allocation);
    if (key !== _allocationKey) {
      _allocationKey = key;
      allocationUpdated();
    }
  }

  implicitWidth: isVertical ? root.barConfig.widgetSize : usedLength
  implicitHeight: isVertical ? usedLength : root.barConfig.widgetSize

  // Total length of the given sizes laid end to end. Zero-sized entries
  // (hidden, or modules with nothing to show) take no spacing.
  function _span(sizes) {
    const shown = sizes.filter(s => s > 0);
    return shown.reduce((sum, s) => sum + s, 0) + Math.max(0, shown.length - 1) * root.spacing;
  }

  // measures: [{pref, min, priority}], shown: [bool] -> {sizes, offsets, visible}
  function allocate(measures, shown, maxExtent, spacing) {
    const visible = shown.slice();
    const total = key => {
      const shown = measures.filter((m, i) => visible[i]);
      return shown.reduce((sum, m) => sum + m[key], 0) + Math.max(0, shown.length - 1) * spacing;
    };

    // Half a pixel of slack, so fractional text widths don't hide a module
    const room = maxExtent + 0.5;
    while (total("min") > room) {
      let drop = -1;
      measures.forEach((m, i) => {
        if (visible[i] && (drop < 0 || m.priority <= measures[drop].priority))
          drop = i;
      });
      if (drop < 0)
        break;
      visible[drop] = false;
    }

    const pref = total("pref");
    const min = total("min");
    const squeeze = pref > room && pref > min ? Math.min(1, (pref - maxExtent) / (pref - min)) : 0;

    const sizes = measures.map((m, i) => visible[i] ? Math.floor(m.pref - (m.pref - m.min) * squeeze) : 0);
    const offsets = [];
    let pos = 0;
    sizes.forEach(size => {
      offsets.push(pos);
      if (size > 0)
        pos += size + spacing;
    });
    return {
      "sizes": sizes,
      "offsets": offsets,
      "visible": visible
    };
  }

  Repeater {
    id: repeater
    model: root.widgets.length

    onItemAdded: (index, item) => {
      const modules = root._modules.slice();
      modules.splice(index, 0, item);
      root._modules = modules;
    }
    onItemRemoved: (index, item) => {
      root._modules = root._modules.filter(m => m !== item);
    }

    delegate: BarWidgetHost {
      id: module
      required property int index
      readonly property var modelData: root.widgets[index] ?? {
        "component": "",
        "properties": {},
        "layout": {}
      }

      barConfig: root.barConfig
      properties: module.modelData.properties || {}
      layoutOverrides: module.modelData.layout || {}
      componentPath: module.modelData.component
      popouts: root.popouts
      panel: root.panel
      screen: root.screen

      readonly property real _offset: root.allocation.offsets[module.index] ?? 0
      mainSize: root.allocation.sizes[module.index] ?? 0
      shown: root.allocation.visible[module.index] ?? false
      x: root.isVertical ? 0 : module._offset
      y: root.isVertical ? module._offset : 0
    }
  }
}
