pragma ComponentBehavior: Bound

import QtQuick

import qs.config
import qs.services
import qs.components.methods
import qs.components.hosts.popout
import qs.components.reusable

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
  // popouts (pillRects), but drawn on their own (as boxes, from pillShapes)
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
    const shown = root._groups.filter(g => g.drawnLength > 0.5).sort((a, b) => a.drawnPos - b.drawnPos);
    return shown.map((g, i) => ({
          "start": g.drawnPos + (i > 0 ? g.drawnHang.lead : 0),
          "end": g.drawnPos + g.drawnLength - (i < shown.length - 1 ? g.drawnHang.trail : 0)
        }));
  }

  // The pills (or islands) as drawn: stretched to carry the surfaces open
  // on them, and joining any they then reach, while those are open
  readonly property var pillShapes: BarLayout.stretchIslands(root.pillRects, root._shownStretches, root.barConfig.pillMerge)

  // Pills stretched past their ends to carry the fillets of surfaces
  // standing on them, by owner (a bar popout, an edge popout): each
  // { index, start, end, squareStart, squareEnd } (EdgeAttach.place's
  // stretch). pillRects stays unstretched.
  property var stretches: ({})
  readonly property var _stretchList: Object.keys(root.stretches).map(k => root.stretches[k])
  // Sets (or with null clears) `owner`'s stretch
  function setStretch(owner, stretch) {
    if (Utils.deepEqual(root.stretches[owner] ?? null, stretch ?? null))
      return;
    const next = Object.assign({}, root.stretches);
    if (stretch)
      next[owner] = stretch;
    else
      delete next[owner];
    root.stretches = next;
  }

  // Where surfaces standing on a pill or island cover its inner stroke,
  // by owner: { start, end } along the bar. While surfaces are translucent
  // the stroke is left open there (their fill no longer hides it).
  property var openings: ({})
  readonly property var _openingList: Object.keys(root.openings).map(k => root.openings[k])
  // Sets (or with null clears) `owner`'s opening
  function setOpening(owner, opening) {
    if (Utils.deepEqual(root.openings[owner] ?? null, opening ?? null))
      return;
    const next = Object.assign({}, root.openings);
    if (opening)
      next[owner] = opening;
    else
      delete next[owner];
    root.openings = next;
  }

  // A stretch changing while its popout is open (the calendar opening its
  // editor) was drawn but not shown: the bar's next frame was rendered,
  // yet the compositor kept showing the one before until something else
  // made the bar commit again (a hover, the clock). So for a few frames
  // after a stretch changes, the bar draws a frame of its own (an
  // invisible pixel flipping), and the last one shown is the right one.
  on_ShownStretchesChanged: repaint.burst()

  // How far each pill reaches past its own ends for the stretches on it,
  // animated, so it grows out to carry a surface and draws back after it.
  // The pill itself follows its sections as drawn (Section.drawnPos).
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

      Glide on before {}
      Glide on after {}
    }
  }
  // Whether the pill `stretch` stands on reaches, as drawn, as far past its
  // ends as it asks (a surface waits for it before sliding out onto it)
  function carries(stretch) {
    const reach = reaches.objectAt(stretch.index);
    const rect = reach?.rect;
    if (!rect)
      return true;
    return reach.before >= rect.start - stretch.start - 0.5 && reach.after >= stretch.end - rect.start - rect.length - 0.5;
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
  FrameNudge {
    id: repaint
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
      root.layoutMoved();
    }
  }
  // Widgets and sections glide to a new layout (BarWidgetHost, Section),
  // so what's anchored to them (an open popout) is told again once
  // they've arrived
  function layoutMoved() {
    layoutUpdated();
    _settle.restart();
  }
  Timer {
    id: _settle
    interval: Appearance.animNormal
    onTriggered: root.layoutUpdated()
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

    // Where it's drawn along the bar, and how long: gliding to the layout's
    // (as its widgets do, BarWidgetHost), which pills follow. Off until
    // first placed, so a new bar doesn't slide its sections in.
    property real drawnPos: section.mainPos
    property real drawnLength: section.usedLength
    property bool _settled: false
    Component.onCompleted: Qt.callLater(() => section._settled = true)
    Glide on drawnPos {
      enabled: section._settled
    }
    Glide on drawnLength {
      enabled: section._settled
    }

    x: section.bar.isVertical ? section.crossPos : section.drawnPos
    y: section.bar.isVertical ? section.drawnPos : section.crossPos

    onAllocationUpdated: section.bar.layoutMoved()
  }

  // The shadow or glow the bar's surface casts, only outside it, so none
  // shows through a translucent one. Pills join the border (or screen
  // edge) they grow from: their shadow is cast evenly, as the border's, so
  // it can't slide onto a stroke they join; otherwise it falls toward the
  // windows. Cast from a black copy of the surface (its pieces each put
  // one here), as its own fill may be the blur window's.
  // Backed, the blur window casts it instead, from the same shapes
  // (BlurShape.shadow), with everything joined to them
  readonly property int shadowEdge: root.barConfig.left ? Bar.Left : root.barConfig.right ? Bar.Right : root.barConfig.bottom ? Bar.Bottom : Bar.Top
  OutsideShadow {
    target: shadowShape
    hideTarget: true
    active: !root.backed
    look: root.barConfig
    edge: root.shadowEdge
    falls: !root.barConfig.pills
    // Not under the surfaces open on its pills or islands (where they
    // cover the far stroke, whether or not the pill stretches for them),
    // from the outer edge they stand on out
    holes: root._openingList.map(o => {
      const reach = root.barConfig.shadowSize * 2;
      const extent = root.barConfig.extent;
      const along = o.end - o.start;
      if (root.isVertical)
        return root.barConfig.left ? Qt.rect(extent, o.start, root.width - extent + reach, along) : Qt.rect(-reach, o.start, root.width - extent + reach, along);
      return root.barConfig.top ? Qt.rect(o.start, extent, along, root.height - extent + reach) : Qt.rect(o.start, -reach, along, root.height - extent + reach);
    })
  }

  Item {
    id: shadowShape
    anchors.fill: parent
    visible: !root.backed
  }

  // The blur window draws the bar's fill (BlurManager), once
  // its window is placed on screen: where its shapes are, the container's
  // top-left on screen (the bar editor's preview has none, and fills itself)
  readonly property var blurOrigin: root.panel?.screenOrigin ? Qt.point(root.panel.screenOrigin.x + (root.parent?.x ?? 0), root.panel.screenOrigin.y + (root.parent?.y ?? 0)) : null
  readonly property bool backed: BlurManager.backing && root.blurOrigin !== null
  readonly property string blurScreen: root.panel?.screen?.name ?? ""

  // What the bar paints under its widgets: its background, inner stroke
  // and pills, which the shadow or glow follows
  Item {
    id: surface
    anchors.fill: parent

    Rectangle {
      id: solidFill
      anchors.fill: parent
      visible: root.barConfig.solid
      color: root.backed ? "transparent" : Appearance.fill(Theme.background)

      Rectangle {
        parent: shadowShape
        anchors.fill: parent
        visible: solidFill.visible
        color: "black"
      }

      BlurShape {
        source: solidFill
        kind: "rect"
        screen: root.blurScreen
        x: root.blurOrigin?.x ?? 0
        y: root.blurOrigin?.y ?? 0
        shown: root.backed && solidFill.visible
        shadow: root.barConfig
        shadowEdge: root.shadowEdge
        shadowFalls: !root.barConfig.pills
      }
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
      model: root.islands ? root.pillShapes.length : 0

      Rectangle {
        id: island
        required property int index
        readonly property var rect: root.pillShapes[index] ?? {
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
        color: root.backed ? "transparent" : Appearance.fill(Theme.background)
        // The stroke drawn by the one below, left open where a popout joins
        border.width: 0

        HoledItem {
          anchors.fill: parent
          // On the inner side, the stroke and its fringe under each opening
          holes: root._openingList.map(o => {
            const along = root.isVertical ? island.y : island.x;
            const start = Math.max(0, o.start - along);
            const end = Math.min(root.isVertical ? island.height : island.width, o.end - along);
            if (end <= start)
              return null;
            const row = Appearance.borderWidth + 1;
            const across = root.barConfig.left || root.barConfig.top ? (root.isVertical ? island.width : island.height) - row : 0;
            return root.isVertical ? Qt.rect(across, start, row, end - start) : Qt.rect(start, across, end - start, row);
          }).filter(hole => hole !== null)

          Rectangle {
            anchors.fill: parent
            color: "transparent"
            border.color: Theme.foreground
            border.width: Appearance.borderWidth
            topLeftRadius: island.topLeftRadius
            topRightRadius: island.topRightRadius
            bottomLeftRadius: island.bottomLeftRadius
            bottomRightRadius: island.bottomRightRadius
          }
        }

        // Its shape, for the bar's shadow
        Rectangle {
          parent: shadowShape
          x: island.x
          y: island.y
          width: island.width
          height: island.height
          topLeftRadius: island.topLeftRadius
          topRightRadius: island.topRightRadius
          bottomLeftRadius: island.bottomLeftRadius
          bottomRightRadius: island.bottomRightRadius
          color: "black"
        }

        BlurShape {
          source: island
          kind: "rect"
          screen: root.blurScreen
          x: (root.blurOrigin?.x ?? 0) + island.x
          y: (root.blurOrigin?.y ?? 0) + island.y
          shown: root.backed
          shadow: root.barConfig
          shadowEdge: root.shadowEdge
          shadowFalls: !root.barConfig.pills
        }
        // Inner side: bottom on a top bar, right on a left one, and so on
        topLeftRadius: root.barConfig.bottom || root.barConfig.right ? startInner : corner
        topRightRadius: root.barConfig.bottom ? endInner : root.barConfig.left ? startInner : corner
        bottomLeftRadius: root.barConfig.top ? startInner : root.barConfig.right ? endInner : corner
        bottomRightRadius: root.barConfig.top || root.barConfig.left ? endInner : corner

        Glide on startInner {}
        Glide on endInner {}
      }
    }

    // Pills: each grows out of the bar's outer edge (the border, or the
    // screen edge with the border off) like a popout does, covering the
    // border's stroke where it joins. Modelled by count, so a clock changing
    // width moves its pill without rebuilding it.
    Repeater {
      model: root.pills ? root.pillShapes.length : 0

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
        boxStart: connectorGap / 2

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

        Glide on startCornerRadius {}
        Glide on endCornerRadius {}

        width: implicitWidth
        height: implicitHeight
        x: root.isVertical ? (root.barConfig.right ? root.width - width : 0) : alongStart
        y: root.isVertical ? alongStart : (root.barConfig.bottom ? root.height - height : 0)
        backed: root.backed
        // The far stroke and its fringe under each opening (in the pill's
        // coordinates)
        strokeHoles: root._openingList.map(o => {
          const start = Math.max(o.start, root.isVertical ? pill.y : pill.x);
          const end = Math.min(o.end, (root.isVertical ? pill.y + pill.height : pill.x + pill.width));
          if (end <= start)
            return null;
          // The stroke, with its anti-aliased fringe a pixel either side
          const row = Appearance.borderWidth + 2;
          const foot = root.barConfig.pillDepth;
          const far = root.isVertical ? root.width : root.height;
          const across = root.barConfig.left || root.barConfig.top ? foot - row + 1 : far - foot - 1;
          const r = root.isVertical ? Qt.rect(across, start, row, end - start) : Qt.rect(start, across, end - start, row);
          return Qt.rect(r.x - pill.x, r.y - pill.y, r.width, r.height);
        }).filter(hole => hole !== null)

        // Its shape, for the bar's shadow
        AttachedSurfaceCopy {
          parent: shadowShape
          source: pill
          x: pill.x
          y: pill.y
          fillColor: "black"
          mirrorStroke: "black"
        }

        BlurShape {
          source: pill
          screen: root.blurScreen
          x: (root.blurOrigin?.x ?? 0) + pill.x
          y: (root.blurOrigin?.y ?? 0) + pill.y
          shown: root.backed
          shadow: root.barConfig
          shadowEdge: root.shadowEdge
          shadowFalls: !root.barConfig.pills
        }
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
