pragma ComponentBehavior: Bound

import QtQuick

import qs.config
import qs.services
import qs.components.methods
import qs.components.hosts.popout

// Lays out a bar's five widget sections along its main axis in one pass,
// so they can never overlap: `left`/`right` hug the ends, `center` stays
// centered on the bar with `leftCenter`/`rightCenter` beside it. When the
// side sections crowd it, the center block slides towards the roomier side
// (unless the bar's `lockCenter` pins it, making each side make room on its
// own half instead); then elastic widgets shrink, and if even their minimum sizes don't fit,
// the lowest-priority widgets anywhere on the bar are hidden (see
// WidgetGroup for how a section fits itself into what it's given).
Rectangle {
  id: root

  required property var barConfig
  property var screen
  property var popouts
  property var panel

  readonly property bool isVertical: barConfig.vertical
  readonly property real length: isVertical ? height : width

  // Emitted whenever widgets may have moved, so an open popout can follow
  // its anchor
  signal layoutUpdated

  color: barConfig.background === "solid" ? Theme.background : "transparent"

  readonly property bool pills: barConfig.pills
  // Fillet room each side of a pill, as for popouts (AttachedSurface)
  readonly property int pillConnector: Appearance.borderRadius * 2
  // Kept clear at both ends. A pill at an end instead sits flush on the
  // perpendicular edge's stroke (bar-window 0 along a floating bar) and
  // joins it, so its widgets only need the pill inset (the stroke and the
  // padding, or the screen margin too on a bare edge).
  readonly property real endMargin: pills ? barConfig.pillInset : Appearance.screenMargin

  // One { start, length, joinStart, joinEnd } per pill along the bar: each
  // non-empty section, merged with its neighbour when they're at most
  // pillMerge apart, grown by the pill gap. Pills reaching an end are
  // stretched onto it and join it.
  readonly property var pillRects: {
    if (!pills)
      return [];
    const spans = root._groups.filter(g => g.usedLength > 0).map(g => ({
          "start": g.mainPos,
          "end": g.mainPos + g.usedLength
        })).sort((a, b) => a.start - b.start);
    const merged = [];
    spans.forEach(span => {
      const last = merged[merged.length - 1];
      if (last && span.start - last.end <= root.barConfig.pillMerge)
        last.end = Math.max(last.end, span.end);
      else
        merged.push(span);
    });
    // A free end sits the pill gap out from its widgets. An end that would
    // reach the frame (the end sections, which sit endMargin in) joins it,
    // the frame standing in for the gap.
    const gap = root.barConfig.pillGap;
    const reach = root.barConfig.overlap + 0.5;
    return merged.map(m => {
      const joinStart = m.start - gap <= reach;
      const joinEnd = m.end + gap >= root.length - reach;
      const start = joinStart ? 0 : m.start - gap;
      const end = joinEnd ? root.length : m.end + gap;
      return {
        "start": start,
        "length": end - start,
        "joinStart": joinStart,
        "joinEnd": joinEnd
      };
    });
  }

  // One pill stretched past its ends to carry an open popout's fillets,
  // { index, start, end } (set by BarPopouts; pillRects stays unstretched)
  property var pillStretch: null
  // The same for a floating edge menu standing on a pill
  property var edgeMenuStretch: null
  // Both stretches on pill `index`, as one { start, end }, or null
  function stretchFor(index) {
    const stretches = [root.pillStretch, root.edgeMenuStretch].filter(s => s?.index === index);
    if (stretches.length === 0)
      return null;
    return {
      "start": Math.min(...stretches.map(s => s.start)),
      "end": Math.max(...stretches.map(s => s.end))
    };
  }

  readonly property var _groups: [leftGroup, leftCenterGroup, centerGroup, rightCenterGroup, rightGroup]
  // Per section, the model indices hidden so the minimum sizes fit
  readonly property var hidden: BarLayout.overflowHidden(root._groups.map(g => g.measures), root.length, root.endMargin, root.barConfig.spacing, root.barConfig.groupSpacing, root.barConfig.lockCenter)
  readonly property var slots: BarLayout.layoutSections(root._groups.map(g => g.preferredLength), root._groups.map(g => g.minimumLength), root.length, root.endMargin, root.barConfig.spacing, root.barConfig.lockCenter)
  // Bindings re-run on any module change; only signal real moves
  property string _slotsKey: ""
  onSlotsChanged: {
    const key = JSON.stringify(slots);
    if (key !== _slotsKey) {
      _slotsKey = key;
      layoutUpdated();
    }
  }

  // A section's shown widgets; `configIndex` is each one's place in the
  // section's config, which hidden widgets leave out
  function widgetModel(widgetConfigArray) {
    return (widgetConfigArray || []).map((widgetConf, i) => ({
          "component": "widgets/" + widgetConf.type + ".qml",
          "properties": widgetConf.properties || {},
          "layout": widgetConf.layout || {},
          "configIndex": i,
          "visible": widgetConf.visible !== false
        })).filter(widget => widget.visible);
  }

  // While the bar editor is on screen, what it shows of this bar (see
  // BarManager.live): the widgets hidden for want of room, by section, and
  // how the selected widget is sized
  readonly property var editorReport: BarManager.editing ? {
    "source": root.barConfig.sourceId,
    "screen": root.screen?.name ?? "",
    "hidden": root._groups.reduce((out, g) => Utils.withEntry(out, g.zone, g.crowdedOut), {}),
    "selected": root._groups.map(g => g.selectedMeasure).find(m => m !== null) ?? null
  } : null
  property string _reportedId: ""
  readonly property string _reportKey: JSON.stringify(root.editorReport)
  on_ReportKeyChanged: root._report()
  Component.onDestruction: BarManager.clearLive(root._reportedId, root.screen?.name ?? "")

  function _report() {
    const id = root.editorReport ? root.barConfig.id : "";
    if (root._reportedId !== "" && root._reportedId !== id)
      BarManager.clearLive(root._reportedId, root.screen?.name ?? "");
    root._reportedId = id;
    BarManager.setLive(id, root.editorReport);
  }

  // A section: the group sits inside its slot at `align` (0 = start,
  // 1 = end), which only matters once hidden modules leave it spare room.
  // Inline components can't see this file's ids, hence `bar`.
  component Section: WidgetGroup {
    id: section
    required property Item bar
    required property int slotIndex
    required align

    readonly property var slot: section.bar.slots[section.slotIndex]
    readonly property real mainPos: Math.round(section.slot.offset + (section.slot.extent - section.usedLength) * section.align)

    barConfig: section.bar.barConfig
    popouts: section.bar.popouts
    panel: section.bar.panel
    screen: section.bar.screen
    maxExtent: section.slot.extent
    hiddenIndices: section.bar.hidden[section.slotIndex]

    // crossStart in from the bar's outer edge (see Bar.enrichBarConfig)
    readonly property real crossPos: {
      const across = section.bar.isVertical ? section.bar.width : section.bar.height;
      const size = section.bar.isVertical ? width : height;
      const start = Math.round(section.barConfig.crossStart);
      const farSide = section.barConfig.right || section.barConfig.bottom;
      return farSide ? across - start - size : start;
    }

    x: section.bar.isVertical ? section.crossPos : section.mainPos
    y: section.bar.isVertical ? section.mainPos : section.crossPos

    onAllocationUpdated: section.bar.layoutUpdated()
  }

  // With the border off nothing else draws a solid bar's inner stroke
  Rectangle {
    visible: root.barConfig.innerStroke ?? false
    color: Theme.foreground
    width: root.isVertical ? Appearance.borderWidth : root.width
    height: root.isVertical ? root.height : Appearance.borderWidth
    x: root.barConfig.left ? root.width - width : 0
    y: root.barConfig.top ? root.height - height : 0
  }

  // Pills: each grows out of the bar's outer edge (the border, or the
  // screen edge with the border off) like a popout does, covering the
  // border's stroke where it joins. Modelled by count, so a clock changing
  // width moves its pill without rebuilding it.
  Repeater {
    model: root.pillRects.length

    AttachedSurface {
      id: pill
      required property int index
      readonly property var rect: root.pillRects[index] ?? {
        "start": 0,
        "length": 0,
        "joinStart": false,
        "joinEnd": false
      }
      readonly property var stretch: root.stretchFor(index)
      readonly property var span: stretch ? {
        "start": stretch.start,
        "length": stretch.end - stretch.start,
        "joinStart": rect.joinStart,
        "joinEnd": rect.joinEnd
      } : rect
      readonly property real alongStart: span.start - startMargin
      // Depth reached from the outer edge; the surface's far half-gap is empty
      readonly property real depthBox: Math.max(0, root.barConfig.pillDepth - connectorGap / 2)

      edge: root.barConfig.location
      active: true
      connectorGap: root.pillConnector
      boxWidth: root.isVertical ? depthBox : span.length
      boxHeight: root.isVertical ? span.length : depthBox
      joinStart: span.joinStart
      joinEnd: span.joinEnd
      // Without the border, pills grow straight out of the screen edges
      straight: !Appearance.screenBorder
      straightJoins: !Appearance.screenBorder

      width: implicitWidth
      height: implicitHeight
      x: root.isVertical ? (root.barConfig.right ? root.width - width : 0) : alongStart
      y: root.isVertical ? alongStart : (root.barConfig.bottom ? root.height - height : 0)
    }
  }

  Section {
    id: leftGroup
    bar: root
    slotIndex: 0
    zone: "left"
    align: 0
    widgets: root.widgetModel(root.barConfig.widgets?.left)
  }

  Section {
    id: leftCenterGroup
    bar: root
    slotIndex: 1
    zone: "leftCenter"
    align: 1
    widgets: root.widgetModel(root.barConfig.widgets?.leftCenter)
  }

  Section {
    id: centerGroup
    bar: root
    slotIndex: 2
    zone: "center"
    align: 0.5
    widgets: root.widgetModel(root.barConfig.widgets?.center)
  }

  Section {
    id: rightCenterGroup
    bar: root
    slotIndex: 3
    zone: "rightCenter"
    align: 0
    widgets: root.widgetModel(root.barConfig.widgets?.rightCenter)
  }

  Section {
    id: rightGroup
    bar: root
    slotIndex: 4
    zone: "right"
    align: 1
    widgets: root.widgetModel(root.barConfig.widgets?.right)
  }
}
