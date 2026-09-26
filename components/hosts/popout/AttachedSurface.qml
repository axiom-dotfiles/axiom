pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Shapes
import QtQuick.Effects

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
 * size adds the connector and fillet margins around it.
 *
 * Variations, all off by default:
 * - joinStart/joinEnd: that end sits flush on the perpendicular edge's
 *   stroke (u = 0 is its outer edge): no side wall, and the far edge meets
 *   that stroke with a concave fillet instead
 * - startFoot/endFoot: where a side wall's fillet lands (v); above 0 it
 *   stands on something drawn under the surface (a pill's far stroke) and
 *   follows it to that end
 * - notches: regions at the attach edge left unpainted (merged pills)
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
  property real startFoot: 0
  property real endFoot: 0
  property bool detached: false
  // A detached box's distance from the attach edge past the connector gap.
  // The surface starts at the attach edge, so the box slides in from
  // there: placed under a bar, from beneath it.
  property real detachedOffset: 0
  readonly property real _lead: detached ? detachedOffset : 0
  // The attach edge / the perpendicular edges a join meets are bare screen
  // edges (screen border off): the surface runs straight off them, with no
  // fillet onto them
  property bool straight: false
  property bool straightJoins: false

  // Breathing room between the box edge and its content: clears the
  // stroke, plus a share of the corner radius so content keeps away from
  // the curve as corners get rounder. Callers that size the box from
  // their content add this on each side (see bar Popouts, tray submenus).
  readonly property int contentInset: Widget.spacing + Appearance.borderWidth + Math.round(Appearance.borderRadius / 4)

  // Rectangles at the attach edge left unpainted, so what's under them
  // shows through: the pills a bar popout merges around. Each is
  // { start, length, roundStart, roundEnd } (edge-local: from u = start
  // for length, v = 0 to notchDepth); roundStart/End round its far corners
  // at that end, to follow a pill's inner edge. They're a mask fixed to
  // this item rather than part of the sliding outline, so the surface
  // slides out from behind what shows through instead of over it.
  property var notches: []
  property real notchDepth: 0
  // The notches in this item's coordinates, for input masks
  readonly property var notchRects: root._notches.map(n => root._rectFrom(n.u, 0, n.end - n.u, root.notchDepth))

  property color fillColor: Theme.background
  property color strokeColor: Theme.foreground

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

  readonly property real boxAlong: vertical ? boxHeight : boxWidth
  readonly property real boxDepth: vertical ? boxWidth : boxHeight
  // Whether each side wall ends in a fillet: not where the end is joined,
  // nor where it runs straight off a bare screen edge (unless it stands on
  // a foot)
  readonly property bool _filletStart: !joinStart && (!straight || startFoot > 0)
  readonly property bool _filletEnd: !joinEnd && (!straight || endFoot > 0)
  readonly property bool _joinFillet: (joinStart || joinEnd) && !straightJoins
  // Room each end for a fillet square, minus the stroke overlap
  readonly property real startMargin: _filletStart ? connectorGap - strokeWidth : 0
  readonly property real endMargin: _filletEnd ? connectorGap - strokeWidth : 0
  readonly property real alongLength: startMargin + boxAlong + endMargin
  // Box + connector gap, plus room for a join's fillet past the far edge
  readonly property real depth: _lead + boxDepth + connectorGap + (_joinFillet ? filletRadius : 0)

  // Along the edge: box + fillet squares. Away from the edge: box +
  // connector gap.
  implicitWidth: vertical ? depth : alongLength
  implicitHeight: vertical ? alongLength : depth

  // Box sides and far edge (stroke centre line)
  readonly property real sideU: startMargin + half
  readonly property real farSideU: startMargin + boxAlong - half
  readonly property real farV: connectorGap / 2 + boxDepth - half

  // The content box in this item's coordinates, at rest (not slid). On
  // every side but the attach edge it coincides with the outer edge of
  // the stroke, so things attaching to this surface (tray submenus) can
  // line their own stroke up with it.
  readonly property rect boxRect: root._rectFrom(startMargin, _lead + connectorGap / 2, boxAlong, boxDepth)

  // The notches clamped to the surface, edge-local (none without depth)
  readonly property var _notches: {
    if (notchDepth <= 0)
      return [];
    return notches.map(n => {
      const u = Math.max(0, Math.min(n.start, alongLength));
      const end = Math.max(u, Math.min(n.start + n.length, alongLength));
      return {
        "u": u,
        "end": end,
        "radius": Math.max(0, Math.min(Appearance.borderRadius - strokeWidth, (end - u) / 2, notchDepth)),
        "roundStart": n.roundStart,
        "roundEnd": n.roundEnd
      };
    }).filter(n => n.end > n.u);
  }

  // Reflections flip the sweep direction of arcs; rotations don't
  readonly property bool mirrored: edge === Bar.Bottom || edge === Bar.Left

  function px(u, v) {
    switch (edge) {
    case Bar.Left:
      return v;
    case Bar.Right:
      return width - v;
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
      return height - v;
    default:
      return v;
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
    const R = filletRadius, cr = cornerRadius, h = half;
    const fs = startFoot, fe = endFoot;
    let d = "";
    if (joinStart && straightJoins) {
      d += startWith(0, farV);
    } else if (joinStart) {
      d += startWith(h, farV + R);
      d += _arc(R, true, h + R, farV);
    } else if (!_filletStart) {
      d += startWith(sideU, 0);
      d += _line(sideU, farV - cr);
      d += _arc(cr, false, sideU + cr, farV);
    } else {
      d += startWith(0, fs + h);
      d += _line(sideU - R, fs + h);
      d += _arc(R, true, sideU, fs + h + R);
      d += _line(sideU, farV - cr);
      d += _arc(cr, false, sideU + cr, farV);
    }
    if (joinEnd && straightJoins) {
      d += _line(alongLength, farV);
    } else if (joinEnd) {
      d += _line(alongLength - h - R, farV);
      d += _arc(R, true, alongLength - h, farV + R);
    } else if (!_filletEnd) {
      d += _line(farSideU - cr, farV);
      d += _arc(cr, false, farSideU, farV - cr);
      d += _line(farSideU, 0);
    } else {
      d += _line(farSideU - cr, farV);
      d += _arc(cr, false, farSideU, farV - cr);
      d += _line(farSideU, fe + h + R);
      d += _arc(R, true, farSideU + R, fe + h);
      d += _line(alongLength, fe + h);
    }
    return d;
  }

  // Fill: the outline, closed back along the attach edge.
  // Joined ends also cover the perpendicular stroke up to the fillet.
  readonly property string fillPath: {
    if (width <= 0 || height <= 0)
      return "";
    const R = filletRadius;
    let d;
    if (joinStart)
      d = _move(0, 0) + _line(0, straightJoins ? farV : farV + R) + root._outline((u, v) => _line(u, v));
    else if (!_filletStart)
      d = root._outline((u, v) => _move(u, v));
    else
      d = root._outline((u, v) => _move(0, startFoot) + _line(u, v));
    if (joinEnd && !straightJoins)
      d += _line(alongLength, farV + R);
    else if (!joinEnd && _filletEnd)
      d += _line(alongLength, endFoot);
    return d + _line(alongLength, 0) + _line(0, 0) + "Z";
  }

  // Stroke: the outline alone, open along the attach edge and on joined
  // ends, whose ends sit exactly on the strokes they continue
  readonly property string strokePath: width > 0 && height > 0 ? root._outline((u, v) => _move(u, v)) : ""

  // The notches as a mask shape: square ends reach past a notch so only
  // the rounded ones curve, and each overhangs the attach edge likewise
  Item {
    id: notchMask
    anchors.fill: parent
    visible: false
    layer.enabled: root._notches.length > 0

    Repeater {
      model: root._notches.length

      Rectangle {
        required property int index
        readonly property var notch: root._notches[index] ?? {
          "u": 0,
          "end": 0,
          "radius": 0,
          "roundStart": false,
          "roundEnd": false
        }
        readonly property real r: notch.radius
        readonly property real u0: notch.u - (notch.roundStart ? 0 : r)
        readonly property real u1: notch.end + (notch.roundEnd ? 0 : r)
        readonly property rect area: root._rectFrom(u0, -r, u1 - u0, root.notchDepth + r)
        x: area.x
        y: area.y
        width: area.width
        height: area.height
        radius: r
        color: "black"
      }
    }
  }

  SlideAnimation {
    id: slideContainer
    anchors.fill: parent

    layer.enabled: root._notches.length > 0
    layer.effect: MultiEffect {
      maskEnabled: true
      maskInverted: true
      maskSource: notchMask
    }

    active: root.active
    slideFromRight: root.attachRight
    slideFromLeft: root.attachLeft
    slideFromTop: root.attachTop
    slideFromBottom: root.attachBottom
    animationDuration: root.animationDuration

    containerHeight: root.height
    containerWidth: root.width
    enableFade: false

    Shape {
      id: outline
      anchors.fill: parent
      visible: !root.detached
      preferredRendererType: Shape.CurveRenderer

      ShapePath {
        fillColor: root.fillColor
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

    // Detached: a box of its own, not joined to anything
    Rectangle {
      visible: root.detached
      x: root.boxRect.x
      y: root.boxRect.y
      width: root.boxRect.width
      height: root.boxRect.height
      radius: Appearance.borderRadius
      color: root.fillColor
      border.color: root.strokeColor
      border.width: root.strokeWidth
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
