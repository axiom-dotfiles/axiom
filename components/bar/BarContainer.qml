pragma ComponentBehavior: Bound

import QtQuick

import qs.config
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

  property color backgroundColor: Theme.background
  property color foregroundColor: Theme.foreground

  readonly property bool isVertical: barConfig.vertical
  readonly property real length: isVertical ? height : width

  // Emitted whenever widgets may have moved, so an open popout can follow
  // its anchor
  signal layoutUpdated

  color: barConfig.background === "solid" ? backgroundColor : "transparent"

  readonly property bool pills: barConfig.pills
  // Fillet room each side of a pill, as for popouts (AttachedSurface)
  readonly property int pillConnector: Appearance.borderRadius * 2
  // Kept clear at both ends. A pill at an end instead sits flush on the
  // perpendicular edge's stroke (bar-window 0 along a floating bar) and
  // joins it, so its widgets only need the stroke and the padding.
  readonly property real endMargin: pills ? barConfig.overlap + barConfig.pillPad : Appearance.screenMargin

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
  readonly property var hidden: root.overflowHidden(root._groups.map(g => g.measures), root.length, root.endMargin, root.barConfig.spacing, root.barConfig.spacing, root.barConfig.lockCenter)
  readonly property var slots: root.layoutSections(root._groups.map(g => g.preferredLength), root._groups.map(g => g.minimumLength), root.length, root.endMargin, root.barConfig.spacing, root.barConfig.lockCenter)
  // Bindings re-run on any module change; only signal real moves
  property string _slotsKey: ""
  onSlotsChanged: {
    const key = JSON.stringify(slots);
    if (key !== _slotsKey) {
      _slotsKey = key;
      layoutUpdated();
    }
  }

  // Sections are [left, leftCenter, center, rightCenter, right]; returns
  // [{offset, extent}] for each along the main axis. `margin` is kept clear
  // at both ends and `gap` between adjacent non-empty sections. With
  // `lockCenter`, the center section always sits dead center at its full
  // size and each side fits itself into the room left on its own half.
  function layoutSections(pref, min, length, margin, gap, lockCenter) {
    const sum = values => values.reduce((a, b) => a + b, 0);
    const gapsFor = sections => gap * sections.filter(i => pref[i] > 0).length;
    // Preferred sizes if they fit, else squeezed towards the minimums,
    // else the minimums scaled down to whatever room there is
    const fit = (p, m, room) => {
      room = Math.max(0, room);
      const sumPref = sum(p);
      const sumMin = sum(m);
      if (sumPref <= room)
        return p.slice();
      if (sumMin <= room) {
        const squeeze = (sumPref - room) / (sumPref - sumMin);
        return p.map((v, i) => v - (v - m[i]) * squeeze);
      }
      return m.map(v => sumMin > 0 ? v * room / sumMin : 0);
    };

    let size, centerStart;
    if (lockCenter) {
      const c = Math.min(pref[2], Math.max(0, length - 2 * margin));
      centerStart = (length - c) / 2;
      const [l, lc] = fit([pref[0], pref[1]], [min[0], min[1]], centerStart - margin - gapsFor([0, 1]));
      const [rc, r] = fit([pref[3], pref[4]], [min[3], min[4]], centerStart - margin - gapsFor([3, 4]));
      size = [l, lc, c, rc, r];
    } else {
      size = fit(pref, min, length - 2 * margin - gapsFor([0, 1, 3, 4]));
      const [l, lc, c, rc, r] = size;
      const lo = margin + (l > 0 ? l + gap : 0) + (lc > 0 ? lc + gap : 0);
      const hi = length - margin - (r > 0 ? r + gap : 0) - (rc > 0 ? rc + gap : 0) - c;
      centerStart = Math.max(lo, Math.min((length - c) / 2, hi));
    }

    const [l, lc, c, rc, r] = size;
    const before = lc > 0 ? lc + gap : 0;

    return [
      {
        "offset": margin,
        "extent": l
      },
      {
        "offset": centerStart - before,
        "extent": lc
      },
      {
        "offset": centerStart,
        "extent": c
      },
      {
        "offset": centerStart + c + (rc > 0 ? gap : 0),
        "extent": rc
      },
      {
        "offset": length - margin - r,
        "extent": r
      }
    ];
  }

  // measures: per section, [{pref, min, priority}]. Hides the
  // lowest-priority widgets until every section's minimum length, plus
  // margins and gaps as in layoutSections, fits the bar. Ties go to the
  // outer sections first and the center last, and within a section to the
  // widget listed last. With `lockCenter`, each half of the bar must fit
  // beside the full-size center on its own, and only the overflowing half
  // loses widgets; the center is only touched if it can't fit the bar.
  function overflowHidden(measures, length, margin, gap, spacing, lockCenter) {
    const hidden = measures.map(() => []);
    const spanOf = (s, key) => {
      const shown = measures[s].filter((m, i) => m.pref > 0 && !hidden[s].includes(i)).map(m => m[key]);
      return shown.reduce((a, b) => a + b, 0) + Math.max(0, shown.length - 1) * spacing;
    };
    const span = s => spanOf(s, "min");
    const sideNeed = sections => sections.reduce((sum, s) => {
        const len = span(s);
        return sum + (len > 0 ? len + gap : 0);
      }, 0);
    const room = length - 2 * margin + 0.5;

    // The sections to drop from (in tie order), or null when it all fits
    const overflowing = () => {
      if (!lockCenter) {
        const spans = measures.map((m, s) => span(s));
        const needed = spans.reduce((a, b) => a + b, 0) + gap * [0, 1, 3, 4].filter(s => spans[s] > 0).length;
        return needed > room ? [4, 0, 3, 1, 2] : null;
      }
      if (span(2) > room)
        return [2];
      const half = (length - Math.min(spanOf(2, "pref"), length - 2 * margin)) / 2 - margin + 0.5;
      if (sideNeed([0, 1]) > half)
        return [0, 1];
      if (sideNeed([3, 4]) > half)
        return [4, 3];
      return null;
    };

    const dropped = [];
    let order;
    while (length > 0 && (order = overflowing())) {
      let drop = null;
      order.forEach(s => {
        for (let i = measures[s].length - 1; i >= 0; i--) {
          const m = measures[s][i];
          if (m.pref > 0 && !hidden[s].includes(i) && (!drop || m.priority < drop.priority))
            drop = {
              "section": s,
              "index": i,
              "priority": m.priority
            };
        }
      });
      if (!drop)
        break;
      hidden[drop.section].push(drop.index);
      dropped.push(drop);
    }
    // Hiding a big widget can free more room than was missing; bring back
    // whatever still fits, most important (last dropped) first
    for (let d = dropped.length - 1; d >= 0; d--) {
      const list = hidden[dropped[d].section];
      list.splice(list.indexOf(dropped[d].index), 1);
      if (overflowing())
        list.push(dropped[d].index);
    }
    return hidden;
  }

  function widgetModel(widgetConfigArray) {
    return (widgetConfigArray || []).filter(widgetConf => widgetConf.visible !== false).map(widgetConf => ({
          "component": "widgets/" + widgetConf.type + ".qml",
          "properties": widgetConf.properties || {},
          "layout": widgetConf.layout || {}
        }));
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

    // Centred across the bar, or with pills, the pill padding in from the
    // bar's outer edge (past the border stroke the pill covers)
    readonly property real crossInset: section.barConfig.overlap + section.barConfig.pillPad
    readonly property real crossPos: {
      const across = section.bar.isVertical ? section.bar.width : section.bar.height;
      const size = section.bar.isVertical ? width : height;
      if (!section.bar.pills)
        return Math.round((across - size) / 2);
      const farSide = section.barConfig.right || section.barConfig.bottom;
      return farSide ? across - crossInset - size : crossInset;
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
    align: 0
    widgets: root.widgetModel(root.barConfig.widgets?.left)
  }

  Section {
    id: leftCenterGroup
    bar: root
    slotIndex: 1
    align: 1
    widgets: root.widgetModel(root.barConfig.widgets?.leftCenter)
  }

  Section {
    id: centerGroup
    bar: root
    slotIndex: 2
    align: 0.5
    widgets: root.widgetModel(root.barConfig.widgets?.center)
  }

  Section {
    id: rightCenterGroup
    bar: root
    slotIndex: 3
    align: 0
    widgets: root.widgetModel(root.barConfig.widgets?.rightCenter)
  }

  Section {
    id: rightGroup
    bar: root
    slotIndex: 4
    align: 1
    widgets: root.widgetModel(root.barConfig.widgets?.right)
  }
}
