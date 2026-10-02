pragma ComponentBehavior: Bound

import QtQuick

import qs.services
import qs.components.methods

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
  // The section's key in the bar's `widgets`
  property string zone: ""
  // The section's widgets (BarContainer.widgetModel entries). Modelled by
  // count, so edits to a widget's options reach it in place instead of
  // rebuilding every widget in the section.
  property var widgets: []

  readonly property int spacing: root.barConfig.spacing
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
  readonly property real preferredLength: BarLayout.span(root.measures.map((m, i) => root._shown[i] ? m.pref : 0), root.spacing)
  readonly property real minimumLength: BarLayout.span(root.measures.map((m, i) => root._shown[i] ? m.min : 0), root.spacing)

  readonly property var allocation: BarLayout.allocate(root.measures, root._shown, root.maxExtent, root.spacing)
  readonly property real usedLength: BarLayout.span(root.allocation.sizes, root.spacing)
  // The widgets with something to show that are hidden for want of room,
  // by their index in the section's config (for the bar editor)
  readonly property var crowdedOut: root.widgets.filter((w, i) => (root.measures[i]?.pref ?? 0) > 0 && !root.allocation.visible[i]).map(w => w.configIndex)
  // How the widget the bar editor has selected is sized here, else null
  readonly property var selectedMeasure: root._modules.find(m => m.highlighted)?.measure ?? null

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

  // The widgets' backgrounds, under them, following each host
  Repeater {
    model: root.widgets.length

    delegate: WidgetBackground {
      required property int index
      readonly property var host: root._modules[index] ?? null

      z: -1
      barConfig: root.barConfig
      colors: host?.background ?? null
      visible: colors !== null && host.shown && host.width > 0 && host.height > 0
      opacity: host?.contentOpacity ?? 1
      x: host?.x ?? 0
      y: host?.y ?? 0
      width: host?.width ?? 0
      height: host?.height ?? 0
    }
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
      highlighted: BarManager.isSelectedWidget(root.barConfig.sourceId, root.zone, module.modelData.configIndex ?? -1)
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
