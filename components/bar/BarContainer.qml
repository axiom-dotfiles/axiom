pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Effects

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

  // The surface layer paints the bar
  color: "transparent"

  readonly property bool pills: barConfig.pills
  // A floating bar: islands held off the edge, read like pills by the
  // popouts (pillRects), but drawn on their own (islandRects)
  readonly property bool islands: barConfig.island
  // Where islands may reach along the bar, from its start
  readonly property real islandEnd: root.length - root.barConfig.islandStart
  // Fillet room each side of a pill, as for popouts (AttachedSurface)
  readonly property int pillConnector: Appearance.borderRadius * 2
  // Kept clear at both ends. A pill at an end instead sits flush on the
  // perpendicular edge's stroke (bar-window 0 along a bar inside the
  // border) and joins it, so its widgets only need the pill inset (the
  // stroke and the padding, or the screen margin too on a bare edge). An
  // island's widgets sit inside its stroke and padding.
  readonly property real endMargin: pills ? barConfig.pillInset : islands ? barConfig.islandStart + barConfig.islandGap : Appearance.screenMargin

  // One { start, length, joinStart, joinEnd } per pill along the bar: each
  // non-empty section, merged with its neighbour when they're at most
  // pillMerge apart, grown by the pill gap. Pills reaching an end are
  // stretched onto it and join it. On a floating bar, its islands
  // (BarLayout.islandRects): one along it, or one per group.
  readonly property var pillRects: {
    if (islands)
      return BarLayout.islandRects(root._spans, root.barConfig.islandGap, root.barConfig.pillMerge, root.barConfig.islandStart, root.islandEnd, !root.barConfig.islandPills);
    if (!pills)
      return [];
    const spans = root._spans.slice();
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

  // The sections with widgets showing, as { start, end } along the bar.
  // Dividers at a section's end facing another section stand in the gap
  // between them, outside its pill (BarLayout.edgeHang); at the first and
  // last sections showing, they stay in it, as padding.
  readonly property var _spans: {
    const shown = root._groups.filter(g => g.usedLength > 0).sort((a, b) => a.mainPos - b.mainPos);
    return shown.map((g, i) => ({
          "start": g.mainPos + (i > 0 ? g.drawnHang.lead : 0),
          "end": g.mainPos + g.usedLength - (i < shown.length - 1 ? g.drawnHang.trail : 0)
        }));
  }

  // The islands as drawn: stretched to carry the surfaces open on them,
  // and joining any they then reach, while those are open
  readonly property var islandRects: islands ? BarLayout.stretchIslands(root.pillRects, root._shownStretches, root.barConfig.pillMerge) : []
  // The pills as drawn, the same way
  readonly property var pillShapes: pills ? BarLayout.stretchIslands(root.pillRects, root._shownStretches, root.barConfig.pillMerge) : []

  // Pills stretched past their ends to carry the fillets of surfaces
  // standing on them, by owner (a bar popout, an edge popout): each
  // { index, start, end, squareStart, squareEnd } (EdgeAttach.place's
  // stretch). pillRects stays unstretched.
  property var stretches: ({})
  readonly property var _stretchList: Object.keys(root.stretches).map(k => root.stretches[k])
  // Sets (or with null clears) `owner`'s stretch
  function setStretch(owner, stretch) {
    if (JSON.stringify(root.stretches[owner] ?? null) === JSON.stringify(stretch ?? null))
      return;
    const next = Object.assign({}, root.stretches);
    if (stretch)
      next[owner] = stretch;
    else
      delete next[owner];
    root.stretches = next;
  }

  // A stretch changing while its popout is open (the calendar opening its
  // editor) was drawn but not shown: the bar's next frame was rendered,
  // yet the compositor kept showing the one before until something else
  // made the bar commit again (a hover, the clock). So for a few frames
  // after a stretch changes, the bar draws a frame of its own (an
  // invisible pixel flipping), and the last one shown is the right one.
  on_ShownStretchesChanged: _repaint.burst()

  // How far each pill reaches past its own ends for the stretches on it,
  // animated, so it grows out to carry a surface and draws back after it.
  // Only the reach animates: the pill itself follows the layout at once.
  Instantiator {
    id: reaches
    model: root.pillRects.length

    delegate: QtObject {
      required property int index
      readonly property var rect: root.pillRects[index] ?? null
      readonly property var target: BarLayout.stretchOf(root._stretchList, index)
      readonly property bool squareStart: target?.squareStart ?? false
      readonly property bool squareEnd: target?.squareEnd ?? false
      property real before: target && rect ? Math.max(0, rect.start - target.start) : 0
      property real after: target && rect ? Math.max(0, target.end - rect.start - rect.length) : 0

      Behavior on before {
        NumberAnimation {
          duration: Appearance.animFast
          easing.type: Appearance.easing
        }
      }
      Behavior on after {
        NumberAnimation {
          duration: Appearance.animFast
          easing.type: Appearance.easing
        }
      }
    }
  }
  // The stretches as drawn (see stretchOf), one per pill reaching past
  // its ends or squared
  readonly property var _shownStretches: {
    const shown = [];
    for (let i = 0; i < reaches.count; i++) {
      const reach = reaches.objectAt(i);
      const rect = reach?.rect;
      if (!rect || (reach.before <= 0 && reach.after <= 0 && !reach.squareStart && !reach.squareEnd))
        continue;
      shown.push({
        "index": i,
        "start": rect.start - reach.before,
        "end": rect.start + rect.length + reach.after,
        "squareStart": reach.squareStart,
        "squareEnd": reach.squareEnd
      });
    }
    return shown;
  }
  property bool _repaintFlip: false
  Timer {
    id: _repaint
    interval: 32
    property int left: 0
    function burst() {
      left = 6;
      restart();
    }
    onTriggered: {
      root._repaintFlip = !root._repaintFlip;
      if (--left > 0)
        restart();
    }
  }
  Rectangle {
    width: 1
    height: 1
    color: "#02000000"
    opacity: root._repaintFlip ? 0.5 : 0.4
  }

  readonly property var _groups: [leftGroup, leftCenterGroup, centerGroup, rightCenterGroup, rightGroup]
  // Per section, the model indices hidden so the minimum sizes fit
  readonly property var hidden: BarLayout.overflowHidden(root._groups.map(g => g.measures), root.length, root.endMargin, root.barConfig.spacing, root.barConfig.groupSpacing, root.barConfig.lockCenter)
  readonly property var slots: BarLayout.layoutSections(root._groups.map(g => g.preferredLength), root._groups.map(g => g.minimumLength), root.length, root.endMargin, root.barConfig.spacing, root.barConfig.lockCenter, centerGroup.layoutHang)
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

  // What the bar paints under its widgets: its background, inner stroke
  // and pills, in one layer so a shadow or glow follows their outline
  // (and never redraws for the widgets over it)
  Item {
    id: surface
    anchors.fill: parent

    layer.enabled: root.barConfig.shadow !== "none"
    layer.effect: MultiEffect {
      // Pills join the border (or screen edge) they grow from: their
      // shadow is cast evenly, as the border's, so it can't slide onto a
      // stroke they join (see SurfaceShadow)
      readonly property bool even: root.barConfig.shadow === "glow" || root.barConfig.pills
      readonly property real offset: even ? 0 : root.barConfig.shadowSize / 4

      shadowEnabled: true
      shadowColor: Bar.shadowColor(root.barConfig)
      shadowBlur: 1
      blurMax: root.barConfig.shadowSize
      // Otherwise a shadow falls toward the windows
      shadowHorizontalOffset: root.barConfig.left ? offset : root.barConfig.right ? -offset : 0
      shadowVerticalOffset: root.barConfig.top ? offset : root.barConfig.bottom ? -offset : 0
      autoPaddingEnabled: true
    }

    Rectangle {
      anchors.fill: parent
      visible: root.barConfig.solid
      color: Theme.background
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

    // Islands: rounded boxes in from the edge, an inner corner squared
    // where a popout runs flush into that end. Modelled by count, as pills.
    Repeater {
      model: root.islandRects.length

      Rectangle {
        id: island
        required property int index
        readonly property var rect: root.islandRects[index] ?? {
          "start": 0,
          "length": 0,
          "squareStart": false,
          "squareEnd": false
        }
        readonly property real depth: root.barConfig.extent - root.barConfig.islandStart
        readonly property real across: root.barConfig.right || root.barConfig.bottom ? (root.isVertical ? root.width : root.height) - root.barConfig.islandStart - depth : root.barConfig.islandStart
        readonly property real corner: Appearance.borderRadius
        // The inner side's corners at the bar's start and end
        property real startInner: rect.squareStart ? 0 : corner
        property real endInner: rect.squareEnd ? 0 : corner

        x: root.isVertical ? across : rect.start
        y: root.isVertical ? rect.start : across
        width: root.isVertical ? depth : rect.length
        height: root.isVertical ? rect.length : depth
        color: Theme.background
        border.color: Theme.foreground
        border.width: Appearance.borderWidth
        // Inner side: bottom on a top bar, right on a left one, and so on
        topLeftRadius: root.barConfig.bottom || root.barConfig.right ? startInner : corner
        topRightRadius: root.barConfig.bottom ? endInner : root.barConfig.left ? startInner : corner
        bottomLeftRadius: root.barConfig.top ? startInner : root.barConfig.right ? endInner : corner
        bottomRightRadius: root.barConfig.top || root.barConfig.left ? endInner : corner

        Behavior on startInner {
          NumberAnimation {
            duration: Appearance.animFast
          }
        }
        Behavior on endInner {
          NumberAnimation {
            duration: Appearance.animFast
          }
        }
      }
    }

    // Pills: each grows out of the bar's outer edge (the border, or the
    // screen edge with the border off) like a popout does, covering the
    // border's stroke where it joins. Modelled by count, so a clock changing
    // width moves its pill without rebuilding it.
    Repeater {
      model: root.pillShapes.length

      AttachedSurface {
        id: pill
        required property int index
        // Stretched to carry the surfaces open on it, as islands are
        readonly property var span: root.pillShapes[index] ?? {
          "start": 0,
          "length": 0,
          "joinStart": false,
          "joinEnd": false,
          "squareStart": false,
          "squareEnd": false
        }
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
        // Square where a popout runs flush into it
        startCornerRadius: span.squareStart ? 0 : cornerRadius
        endCornerRadius: span.squareEnd ? 0 : cornerRadius

        Behavior on startCornerRadius {
          NumberAnimation {
            duration: Appearance.animFast
          }
        }
        Behavior on endCornerRadius {
          NumberAnimation {
            duration: Appearance.animFast
          }
        }

        width: implicitWidth
        height: implicitHeight
        x: root.isVertical ? (root.barConfig.right ? root.width - width : 0) : alongStart
        y: root.isVertical ? alongStart : (root.barConfig.bottom ? root.height - height : 0)
      }
    }
  }

  // A line along the bar's inner or outer edge, from its color fading
  // into another along the bar. Inline components can't see this file's
  // ids, hence `bar`.
  component AccentLine: Rectangle {
    id: line
    required property Item bar
    // Along the bar, and in from its outer edge
    required property real start
    required property real length
    required property real inset

    readonly property bool vertical: bar.isVertical
    readonly property real thickness: bar.barConfig.accentLineWidth
    readonly property bool far: bar.barConfig.right || bar.barConfig.bottom
    readonly property real across: far ? (vertical ? bar.width : bar.height) - inset - thickness : inset
    readonly property color from: Theme.resolveColor(bar.barConfig.accentLineColor)

    x: vertical ? across : start
    y: vertical ? start : across
    width: vertical ? thickness : length
    height: vertical ? length : thickness
    gradient: Gradient {
      orientation: line.vertical ? Gradient.Vertical : Gradient.Horizontal
      GradientStop {
        position: 0
        color: line.from
      }
      GradientStop {
        position: 1
        color: line.bar.barConfig.accentLineFade ? Theme.resolveColor(line.bar.barConfig.accentLineFade) : line.from
      }
    }
  }

  // How far in from the outer edge the accent line sits: inside whatever
  // stroke is there (the border strip's or the bar's own on a solid bar's
  // inner edge, the border's under a floating bar's outer edge)
  readonly property real _accentInset: {
    const width = root.barConfig.accentLineWidth;
    if (root.barConfig.accentLine === "outer") {
      if (root.islands)
        return root.barConfig.islandStart + Appearance.borderWidth;
      return root.pills ? root.barConfig.overlap : root.barConfig.insideBorder ? Appearance.borderWidth : 0;
    }
    if (root.pills)
      return root.barConfig.pillDepth - Appearance.borderWidth - width;
    return root.barConfig.extent - width - (root.barConfig.solid || root.islands ? Appearance.borderWidth : 0);
  }

  // Along a plain bar: its whole length, or clear of the border's sides
  // inside the border
  AccentLine {
    visible: root.barConfig.accentLine !== "none" && !root.pills && !root.islands
    bar: root
    start: root.barConfig.insideBorder ? root.endMargin : 0
    length: root.length - start * 2
    inset: root._accentInset
  }

  // Along each pill, clear of its rounded corners on the inner side
  Repeater {
    model: root.barConfig.accentLine !== "none" && (root.pills || root.islands) ? root.pillRects.length : 0

    AccentLine {
      required property int index
      readonly property var rect: root.pillRects[index] ?? {
        "start": 0,
        "length": 0
      }
      // Pills only round their inner side; islands both
      readonly property real corner: root.islands || root.barConfig.accentLine === "inner" ? Appearance.borderRadius : 0

      bar: root
      start: rect.start + (rect.joinStart ? 0 : corner)
      length: Math.max(0, rect.length - (rect.joinStart ? 0 : corner) - (rect.joinEnd ? 0 : corner))
      inset: root._accentInset
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
