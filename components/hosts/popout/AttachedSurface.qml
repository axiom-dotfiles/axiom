pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Shapes

import qs.config

/**
 * The shared "grows out of an edge" shape used by bar popouts, screen-edge
 * popouts and bar pills: a content box joined to the attach edge by two
 * concave fillets, with the bar/border stroke cut open where it joins.
 * The whole thing slides in/out from the attach edge.
 *
 * The outline is a single path (fill + stroke), with the stroke centred
 * half a border width inside the edge. That way every segment (the line
 * along the attach edge, the fillets, the sides and the far corners) is
 * the same full width, pixel-aligned with the bar/border stroke it
 * continues. Composing rectangles + clipped corner pieces left some
 * segments half-clipped and anti-aliased.
 *
 * `edge` is the side the surface attaches to, as a Bar.Location value.
 * `boxWidth`/`boxHeight` are the size of the content box; the implicit
 * size adds the connector and fillet margins around it. Attached, the box
 * starts on the attach edge (boxStart), the fillets beside it.
 *
 * Variations, all off by default:
 * - joinStart/joinEnd: that end sits flush on the perpendicular edge's
 *   stroke (u = 0 is its outer edge): no side wall, and the far edge meets
 *   that stroke with a concave fillet instead
 * - flushStart/flushEnd: that side wall runs straight into the attach
 *   edge with no fillet, continuing the end of what it attaches to (a
 *   floating bar's island, whose corner squares to meet it)
 * - detached: a plain rounded box, not joined to anything; detachedOffset
 *   sets it further in from the edge it slides out of
 * - straight/straightJoins: the attach edge, or the edges a join meets, are
 *   bare screen edges, so the walls run straight off them
 *
 * Place this at the attach edge of its window: for a Top edge, y = 0 of
 * this item should sit on the top of the bar/border stroke line.
 */
Item {
  id: root

  required property int edge
  property bool active: false
  property real boxWidth: 100
  property real boxHeight: 100
  property int connectorGap: Appearance.borderRadius * 2
  property int animationDuration: Appearance.animNormal

  property bool joinStart: false
  property bool joinEnd: false
  property bool flushStart: false
  property bool flushEnd: false
  // A flush wall runs on through the backfill, over the end of the stroke
  // it continues (see _outline). Off where that stroke now carries on past
  // it (a tray submenu joined beside it, the pill or island stretched
  // under it): the wall stops at the attach edge, the backfill running on.
  property bool flushStartThrough: true
  property bool flushEndThrough: true
  readonly property bool _throughStart: flushStart && flushStartThrough
  readonly property bool _throughEnd: flushEnd && flushEndThrough
  property bool detached: false
  // A detached box's distance from the attach edge past the connector gap.
  // The surface starts at the attach edge, so the box slides in from
  // there: placed under a bar, from beneath it.
  property real detachedOffset: 0
  readonly property real _lead: detached ? detachedOffset : 0
  // Fill drawn this far behind the attach edge (the surface grows by it,
  // and v = 0 stays on the attach edge). A popout on a pill's far stroke
  // takes a pixel, to cover the pill stroke's anti-aliased fringe on the
  // pill's side, which is left standing alone as a faint line once the
  // popout covers the stroke itself.
  property real backfill: 0
  readonly property real _back: detached ? 0 : backfill
  // Fill drawn this far past a joined end, over what it joins, with no
  // stroke or shadow of its own: a tray submenu joined beside a popout on
  // a pill covers the popout's backfill row there, where the popout's glow
  // would show as a dash
  property real joinBackfill: 0
  // The attach edge / the perpendicular edges a join meets are bare screen
  // edges (screen border off): the surface runs straight off them, with no
  // fillet onto them
  property bool straight: false
  property bool straightJoins: false

  // Breathing room between the box edge and its content: clears the
  // stroke, plus the popout padding every popout shares (Popouts.padding,
  // as EdgePopout and edge menus use). Callers that size the box from
  // their content add this on each side (see bar Popouts, tray submenus).
  readonly property int contentInset: Appearance.borderWidth + PopoutConfig.padding

  property color fillColor: Theme.background
  property color strokeColor: Theme.foreground
  // Casts the shell's shadow or glow (SurfaceShadow), for a surface whose
  // border shows: off for a bar's own pills, which their bar's casts
  property bool castShadow: false

  default property alias content: contentContainer.data

  readonly property bool vertical: edge === Bar.Left || edge === Bar.Right
  readonly property bool attachLeft: edge === Bar.Left
  readonly property bool attachRight: edge === Bar.Right
  readonly property bool attachTop: edge === Bar.Top
  readonly property bool attachBottom: edge === Bar.Bottom

  // ---- Geometry, in edge-local coordinates ----
  // u runs along the attach edge, v away from it (v = 0 is the attach
  // edge). Everything below is laid out as if attached to the Top edge,
  // then mapped onto the real edge by px()/py().
  readonly property real strokeWidth: Appearance.borderWidth
  // Stroke centre line offset, so the full stroke lies inside the shape
  readonly property real half: strokeWidth / 2
  // Concave fillet radius (where the box meets an edge) and convex corner
  // radius at the far side, matching a Rectangle's radius
  readonly property real filletRadius: Appearance.borderRadius
  readonly property real cornerRadius: Math.max(0, Appearance.borderRadius - half)
  // The far corners at each end of the attach edge: 0 squares one, where a
  // box runs flush into this surface (a pill stretched to carry it)
  property real startCornerRadius: cornerRadius
  property real endCornerRadius: cornerRadius
  // A detached box's near corners (at the attach edge), at each end: 0
  // squares one, where a tray submenu runs flush to it
  property real startNearRadius: Appearance.borderRadius
  property real endNearRadius: Appearance.borderRadius

  readonly property real boxAlong: vertical ? boxHeight : boxWidth
  readonly property real boxDepth: vertical ? boxWidth : boxHeight
  // A radius under half the stroke (0 included) is too tight for a
  // fillet: its stroke's inner edge would need a negative radius, and its
  // margin (below) would go negative, pushing the walls out of the surface.
  // The walls run straight into what they attach to instead.
  readonly property bool _sharp: filletRadius < half
  // Whether each side wall ends in a fillet: not where the end is joined
  // or flush, nor where it runs straight off a bare screen edge
  readonly property bool _filletStart: !_sharp && !joinStart && !flushStart && !straight
  readonly property bool _filletEnd: !_sharp && !joinEnd && !flushEnd && !straight
  readonly property bool _straightJoins: straightJoins || _sharp
  readonly property bool _joinFillet: (joinStart || joinEnd) && !_straightJoins
  // Room each end for a fillet square, minus the stroke overlap
  readonly property real startMargin: _filletStart ? connectorGap - strokeWidth : 0
  readonly property real endMargin: _filletEnd ? connectorGap - strokeWidth : 0
  readonly property real alongLength: startMargin + boxAlong + endMargin
  // Box + connector gap, plus room for a join's fillet past the far edge
  // Where the box starts away from the attach edge. Detached, a connector
  // gap's half past its lead. Attached, on the attach edge: the fillets
  // curve outside the side walls, so the band they span is the box's own
  // rather than empty padding above the content. Pushed back only as far
  // as a shallow box needs for a side wall to clear its fillet and far
  // corner.
  readonly property real naturalBoxStart: {
    if (detached)
      return _lead + connectorGap / 2;
    const fillet = _filletStart || _filletEnd ? filletRadius + half : 0;
    return Math.max(0, Math.min(connectorGap / 2, fillet + Math.max(startCornerRadius, endCornerRadius) + half - boxDepth));
  }
  // Overridable: a bar's pills keep a half connector gap (sized by it)
  property real boxStart: naturalBoxStart
  // The box and the half connector gap past it (and a joined end's fillet
  // along the perpendicular stroke)
  readonly property real depth: _back + boxStart + boxDepth + connectorGap / 2 + (_joinFillet ? filletRadius : 0)

  // Along the edge: box + fillet squares. Away from the edge: box +
  // connector gap.
  implicitWidth: vertical ? depth : alongLength
  implicitHeight: vertical ? alongLength : depth

  // Box sides and far edge (stroke centre line)
  readonly property real sideU: startMargin + half
  readonly property real farSideU: startMargin + boxAlong - half
  readonly property real farV: boxStart + boxDepth - half

  // The content box in this item's coordinates, at rest (not slid). On
  // every side but the attach edge it coincides with the outer edge of
  // the stroke, so things attaching to this surface (tray submenus) can
  // line their own stroke up with it.
  readonly property rect boxRect: root._rectFrom(startMargin, boxStart, boxAlong, boxDepth)

  // Reflections flip the sweep direction of arcs; rotations don't
  readonly property bool mirrored: edge === Bar.Bottom || edge === Bar.Left

  function px(u, v) {
    switch (edge) {
    case Bar.Left:
      return v + _back;
    case Bar.Right:
      return width - v - _back;
    default:
      return u;
    }
  }

  function py(u, v) {
    switch (edge) {
    case Bar.Left:
    case Bar.Right:
      return u;
    case Bar.Bottom:
      return height - v - _back;
    default:
      return v + _back;
    }
  }

  // An edge-local rectangle (u, v, along, deep) in item coordinates
  function _rectFrom(u, v, along, deep) {
    const xs = [px(u, v), px(u + along, v + deep)];
    const ys = [py(u, v), py(u + along, v + deep)];
    return Qt.rect(Math.min(xs[0], xs[1]), Math.min(ys[0], ys[1]), Math.abs(xs[1] - xs[0]), Math.abs(ys[1] - ys[0]));
  }

  // SVG path pieces from edge-local points. The sweep flag is for the arc
  // as drawn attached to the Top edge (y down); reflections flip it.
  function _pt(u, v) {
    return px(u, v) + " " + py(u, v);
  }
  function _move(u, v) {
    return "M " + _pt(u, v) + " ";
  }
  function _line(u, v) {
    return "L " + _pt(u, v) + " ";
  }
  function _arc(r, clockwise, u, v) {
    return "A " + r + " " + r + " 0 0 " + ((clockwise !== mirrored) ? 1 : 0) + " " + _pt(u, v) + " ";
  }

  // The outline from the start end to the end end: side walls (or joins)
  // and the far edge. Shared by the fill and the stroke.
  function _outline(startWith) {
    const R = filletRadius, cs = startCornerRadius, ce = endCornerRadius, h = half;
    // A flush wall runs on through the backfill, its stroke covering the
    // end of the stroke it continues there, which the backfill leaves
    // open: left empty, the shadow or glow showed through as a seam
    const fv0 = _throughStart ? -_back : 0, fv1 = _throughEnd ? -_back : 0;
    let d = "";
    if (joinStart && _straightJoins) {
      d += startWith(0, farV);
    } else if (joinStart) {
      d += startWith(h, farV + R);
      d += _arc(R, true, h + R, farV);
    } else if (!_filletStart) {
      d += startWith(sideU, fv0);
      d += _line(sideU, farV - cs);
      d += _arc(cs, false, sideU + cs, farV);
    } else {
      d += startWith(0, h);
      d += _line(sideU - R, h);
      d += _arc(R, true, sideU, h + R);
      d += _line(sideU, farV - cs);
      d += _arc(cs, false, sideU + cs, farV);
    }
    if (joinEnd && _straightJoins) {
      d += _line(alongLength, farV);
    } else if (joinEnd) {
      d += _line(alongLength - h - R, farV);
      d += _arc(R, true, alongLength - h, farV + R);
    } else if (!_filletEnd) {
      d += _line(farSideU - ce, farV);
      d += _arc(ce, false, farSideU, farV - ce);
      d += _line(farSideU, fv1);
    } else {
      d += _line(farSideU - ce, farV);
      d += _arc(ce, false, farSideU, farV - ce);
      d += _line(farSideU, h + R);
      d += _arc(R, true, farSideU + R, h);
      d += _line(alongLength, h);
    }
    return d;
  }

  // Fill: the outline, closed back along the attach edge.
  // Joined ends also cover the perpendicular stroke up to the fillet.
  readonly property string fillPath: {
    if (width <= 0 || height <= 0)
      return "";
    const R = filletRadius, b = -_back;
    // The backfill stops short of a flush end's wall, squarely, where the
    // stroke of what it attaches to carries on behind it
    const u0 = _throughStart ? strokeWidth : 0, u1 = _throughEnd ? alongLength - strokeWidth : alongLength;
    let d;
    if (joinStart)
      d = _move(0, b) + _line(0, _straightJoins ? farV : farV + R) + root._outline((u, v) => _line(u, v));
    else if (flushStart)
      d = _move(u0, b) + (_throughStart ? "" : _line(0, 0)) + root._outline((u, v) => _line(u, v));
    else if (!_filletStart)
      d = root._outline((u, v) => _move(u, v));
    else
      d = root._outline((u, v) => _move(0, 0) + _line(u, v));
    if (joinEnd && !_straightJoins)
      d += _line(alongLength, farV + R);
    else if ((!joinEnd && _filletEnd) || (flushEnd && !_throughEnd))
      d += _line(alongLength, 0);
    return d + _line(u1, b) + _line(u0, b) + "Z";
  }

  // Stroke: the outline alone, open along the attach edge and on joined
  // ends, whose ends sit exactly on the strokes they continue
  readonly property string strokePath: width > 0 && height > 0 ? root._outline((u, v) => _move(u, v)) : ""

  SlideAnimation {
    id: slideContainer
    anchors.fill: parent

    active: root.active
    slideFromRight: root.attachRight
    slideFromLeft: root.attachLeft
    slideFromTop: root.attachTop
    slideFromBottom: root.attachBottom
    animationDuration: root.animationDuration

    containerHeight: root.height
    containerWidth: root.width
    enableFade: false
    overflow: root.castShadow ? BarStyle.shadowReach : 0

    // The shadow or glow the outline casts, only outside it (none shows
    // through a translucent fill): the content doesn't need its own
    OutsideShadow {
      target: outlineLayer
      active: root.castShadow
      edge: root.edge
      falls: root.detached
    }

    // The outline (or detached box)
    Item {
      id: outlineLayer
      anchors.fill: parent

      Shape {
        id: outline
        anchors.fill: parent
        visible: !root.detached
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
          fillColor: Appearance.fill(root.fillColor)
          strokeColor: "transparent"
          strokeWidth: 0

          PathSvg {
            path: root.fillPath
          }
        }

        ShapePath {
          fillColor: "transparent"
          strokeColor: root.strokeColor
          strokeWidth: root.strokeWidth
          capStyle: ShapePath.FlatCap
          joinStyle: ShapePath.MiterJoin

          PathSvg {
            path: root.strokePath
          }
        }
      }

      // Detached: a box of its own, not joined to anything. Its far
      // corners square as the outline's do (start/endCornerRadius, the
      // stroke's centre line: the outer edge is half a stroke out).
      Rectangle {
        id: detachedBox
        readonly property real startRadius: root.startCornerRadius > 0 ? root.startCornerRadius + root.half : 0
        readonly property real endRadius: root.endCornerRadius > 0 ? root.endCornerRadius + root.half : 0
        // Far corners from start/endRadius, near ones from start/endNearRadius
        topLeftRadius: root.attachBottom || root.attachRight ? detachedBox.startRadius : root.startNearRadius
        topRightRadius: root.attachLeft ? detachedBox.startRadius : root.attachBottom ? detachedBox.endRadius : root.attachTop ? root.endNearRadius : root.startNearRadius
        bottomLeftRadius: root.attachTop ? detachedBox.startRadius : root.attachRight ? detachedBox.endRadius : root.attachBottom ? root.startNearRadius : root.endNearRadius
        bottomRightRadius: root.attachTop || root.attachLeft ? detachedBox.endRadius : root.endNearRadius
        visible: root.detached
        x: root.boxRect.x
        y: root.boxRect.y
        width: root.boxRect.width
        height: root.boxRect.height
        color: Appearance.fill(root.fillColor)
        border.color: root.strokeColor
        border.width: root.strokeWidth
      }
    }

    // Past a joined end (joinBackfill), outside the shadowed outline
    Rectangle {
      readonly property rect area: root.joinStart ? root._rectFrom(-root.joinBackfill, -root._back, root.joinBackfill, root._back + root.boxStart + root.boxDepth) : root._rectFrom(root.alongLength, -root._back, root.joinBackfill, root._back + root.boxStart + root.boxDepth)
      visible: !root.detached && root.joinBackfill > 0 && (root.joinStart || root.joinEnd)
      x: area.x
      y: area.y
      width: area.width
      height: area.height
      color: Appearance.fill(root.fillColor)
    }

    // Content box: same placement the old bordered Rectangle had, so
    // popout content is laid out exactly as before
    Item {
      id: contentContainer
      x: root.boxRect.x
      y: root.boxRect.y
      width: root.boxWidth
      height: root.boxHeight
    }
  }
}
