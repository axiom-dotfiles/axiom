pragma Singleton
import QtQuick

// The outline of a surface that grows out of an edge (AttachedSurface): a
// content box joined to the attach edge by two concave fillets, or a plain
// box held off it. One set of metrics, so the drawn shape, the footprint
// other surfaces collide with (PopoutGeometry) and the copies the blur
// window draws all agree.
//
// Edge-local coordinates: u runs along the attach edge, v away from it
// (v = 0 is the attach edge), laid out as if attached to the Top edge and
// mapped onto the real one by `toItem`. `edge` is a Bar.Location number
// (0 top, 1 bottom, 2 left, 3 right). No files, services or config: the
// caller passes the shape's settings in a spec:
//   { edge, boxAlong, boxDepth, strokeWidth, filletRadius, cornerRadius,
//     startCornerRadius, endCornerRadius, connectorGap, joinStart,
//     joinEnd, flushStart, flushEnd, flushStartThrough, flushEndThrough,
//     detached, detachedOffset, backfill, straight, straightJoins }
QtObject {
  id: root

  readonly property int top: 0
  readonly property int bottom: 1
  readonly property int left: 2
  readonly property int right: 3

  // Everything derived from a spec, in edge-local coordinates
  function metrics(s) {
    const half = s.strokeWidth / 2;
    const R = s.filletRadius;
    const detached = !!s.detached;
    const back = detached ? 0 : (s.backfill ?? 0);
    const lead = detached ? (s.detachedOffset ?? 0) : 0;
    // A radius under half the stroke is too tight for a fillet: the walls
    // run straight into what they attach to (AttachedSurface._sharp)
    const sharp = R < half;
    const filletStart = !sharp && !s.joinStart && !s.flushStart && !s.straight;
    const filletEnd = !sharp && !s.joinEnd && !s.flushEnd && !s.straight;
    const straightJoins = !!s.straightJoins || sharp;
    const joinFillet = (!!s.joinStart || !!s.joinEnd) && !straightJoins;
    const startMargin = filletStart ? s.connectorGap - s.strokeWidth : 0;
    const endMargin = filletEnd ? s.connectorGap - s.strokeWidth : 0;
    const alongLength = startMargin + s.boxAlong + endMargin;
    const cs = s.startCornerRadius ?? s.cornerRadius;
    const ce = s.endCornerRadius ?? s.cornerRadius;
    let naturalBoxStart;
    if (detached) {
      naturalBoxStart = lead + s.connectorGap / 2;
    } else {
      const fillet = filletStart || filletEnd ? R + half : 0;
      naturalBoxStart = Math.max(0, Math.min(s.connectorGap / 2, fillet + Math.max(cs, ce) + half - s.boxDepth));
    }
    return withBoxStart(s, {
      "half": half,
      "back": back,
      "sharp": sharp,
      "filletStart": filletStart,
      "filletEnd": filletEnd,
      "straightJoins": straightJoins,
      "joinFillet": joinFillet,
      "throughStart": !!s.flushStart && (s.flushStartThrough ?? true),
      "throughEnd": !!s.flushEnd && (s.flushEndThrough ?? true),
      "startMargin": startMargin,
      "endMargin": endMargin,
      "alongLength": alongLength,
      "startCornerRadius": cs,
      "endCornerRadius": ce,
      "naturalBoxStart": naturalBoxStart,
      "sideU": startMargin + half,
      "farSideU": startMargin + s.boxAlong - half
    }, naturalBoxStart);
  }

  // The metrics with the box starting `boxStart` from the attach edge (a
  // bar's pills keep a half connector gap instead of the natural start)
  function withBoxStart(s, m, boxStart) {
    return Object.assign({}, m, {
      "boxStart": boxStart,
      "depth": m.back + boxStart + s.boxDepth + s.connectorGap / 2 + (m.joinFillet ? s.filletRadius : 0),
      "farV": boxStart + s.boxDepth - m.half
    });
  }

  // The item's size for a spec: along the edge, the box and fillet
  // squares; away from it, the box and connector gap
  function size(s, m) {
    const vertical = s.edge === root.left || s.edge === root.right;
    return {
      "width": vertical ? m.depth : m.alongLength,
      "height": vertical ? m.alongLength : m.depth
    };
  }

  // An edge-local point in the item's coordinates (`w`/`h` its size)
  function toItem(edge, w, h, back, u, v) {
    switch (edge) {
    case root.left:
      return {
        "x": v + back,
        "y": u
      };
    case root.right:
      return {
        "x": w - v - back,
        "y": u
      };
    case root.bottom:
      return {
        "x": u,
        "y": h - v - back
      };
    default:
      return {
        "x": u,
        "y": v + back
      };
    }
  }

  // An edge-local rect (u, v, along, deep) in the item's coordinates
  function rectFrom(edge, w, h, back, u, v, along, deep) {
    const a = toItem(edge, w, h, back, u, v);
    const b = toItem(edge, w, h, back, u + along, v + deep);
    return {
      "x": Math.min(a.x, b.x),
      "y": Math.min(a.y, b.y),
      "width": Math.abs(b.x - a.x),
      "height": Math.abs(b.y - a.y)
    };
  }

  // The content box at rest, in the item's coordinates
  function boxRect(s, m, w, h) {
    return rectFrom(s.edge, w, h, m.back, m.startMargin, m.boxStart, s.boxAlong, s.boxDepth);
  }

  // A path-building context: SVG pieces from edge-local points. The sweep
  // flag is for the arc as drawn on the Top edge (y down); reflections
  // (bottom, left) flip it.
  function _pen(s, m, w, h) {
    const mirrored = s.edge === root.bottom || s.edge === root.left;
    const pt = (u, v) => {
      const p = toItem(s.edge, w, h, m.back, u, v);
      return p.x + " " + p.y;
    };
    return {
      "move": (u, v) => "M " + pt(u, v) + " ",
      "line": (u, v) => "L " + pt(u, v) + " ",
      "arc": (r, clockwise, u, v) => "A " + r + " " + r + " 0 0 " + ((clockwise !== mirrored) ? 1 : 0) + " " + pt(u, v) + " "
    };
  }

  // The outline from the start end to the end end: side walls (or joins)
  // and the far edge, shared by the fill and the stroke. `startWith(u, v)`
  // begins it (a move, or a line continuing the fill).
  function _outline(s, m, p, startWith) {
    const R = s.filletRadius, cs = m.startCornerRadius, ce = m.endCornerRadius, h = m.half;
    const sideU = m.sideU, farSideU = m.farSideU, farV = m.farV, L = m.alongLength;
    // A flush wall runs on through the backfill, its stroke covering the
    // end of the stroke it continues there, which the backfill leaves open
    const fv0 = m.throughStart ? -m.back : 0, fv1 = m.throughEnd ? -m.back : 0;
    let d = "";
    if (s.joinStart && m.straightJoins) {
      d += startWith(0, farV);
    } else if (s.joinStart) {
      d += startWith(h, farV + R);
      d += p.arc(R, true, h + R, farV);
    } else if (!m.filletStart) {
      d += startWith(sideU, fv0);
      d += p.line(sideU, farV - cs);
      d += p.arc(cs, false, sideU + cs, farV);
    } else {
      d += startWith(0, h);
      d += p.line(sideU - R, h);
      d += p.arc(R, true, sideU, h + R);
      d += p.line(sideU, farV - cs);
      d += p.arc(cs, false, sideU + cs, farV);
    }
    if (s.joinEnd && m.straightJoins) {
      d += p.line(L, farV);
    } else if (s.joinEnd) {
      d += p.line(L - h - R, farV);
      d += p.arc(R, true, L - h, farV + R);
    } else if (!m.filletEnd) {
      d += p.line(farSideU - ce, farV);
      d += p.arc(ce, false, farSideU, farV - ce);
      d += p.line(farSideU, fv1);
    } else {
      d += p.line(farSideU - ce, farV);
      d += p.arc(ce, false, farSideU, farV - ce);
      d += p.line(farSideU, h + R);
      d += p.arc(R, true, farSideU + R, h);
      d += p.line(L, h);
    }
    return d;
  }

  // Fill: the outline, closed back along the attach edge (and behind it by
  // the backfill). Joined ends also cover the perpendicular stroke up to
  // the fillet.
  function fillPath(s, m, w, h) {
    if (w <= 0 || h <= 0)
      return "";
    const p = _pen(s, m, w, h);
    const R = s.filletRadius, b = -m.back, L = m.alongLength;
    // The backfill stops short of a flush end's wall, squarely, where the
    // stroke of what it attaches to carries on behind it
    const u0 = m.throughStart ? s.strokeWidth : 0, u1 = m.throughEnd ? L - s.strokeWidth : L;
    let d;
    if (s.joinStart)
      d = p.move(0, b) + p.line(0, m.straightJoins ? m.farV : m.farV + R) + _outline(s, m, p, p.line);
    else if (s.flushStart)
      d = p.move(u0, b) + (m.throughStart ? "" : p.line(0, 0)) + _outline(s, m, p, p.line);
    else if (!m.filletStart)
      d = _outline(s, m, p, p.move);
    else
      d = _outline(s, m, p, (u, v) => p.move(0, 0) + p.line(u, v));
    if (s.joinEnd && !m.straightJoins)
      d += p.line(L, m.farV + R);
    else if ((!s.joinEnd && m.filletEnd) || (s.flushEnd && !m.throughEnd))
      d += p.line(L, 0);
    return d + p.line(u1, b) + p.line(u0, b) + "Z";
  }

  // Stroke: the outline alone, open along the attach edge and on joined
  // ends, whose ends sit exactly on the strokes they continue
  function strokePath(s, m, w, h) {
    if (w <= 0 || h <= 0)
      return "";
    const p = _pen(s, m, w, h);
    return _outline(s, m, p, p.move);
  }

  // What the surface covers, as rects in the item's coordinates: the box,
  // the fillets beside it at the attach edge (their whole squares), a
  // joined end's fillet past the far edge, and the backfill row behind the
  // attach edge. Detached, the box alone (its corners as square: a
  // touch of a corner's curve counts). Other surfaces overlapping any
  // of them collide with it (PopoutGeometry).
  function footprint(s, m, w, h) {
    const R = s.filletRadius, back = m.back;
    const rect = (u, v, along, deep) => rectFrom(s.edge, w, h, back, u, v, along, deep);
    if (s.detached)
      return [boxRect(s, m, w, h)];
    // Attached, the box reaches back to the attach edge
    const out = [rect(m.startMargin, 0, s.boxAlong, m.boxStart + s.boxDepth)];
    const filletDeep = R + m.half;
    if (m.filletStart && m.startMargin > 0)
      out.push(rect(0, 0, m.startMargin, filletDeep));
    if (m.filletEnd && m.endMargin > 0)
      out.push(rect(m.startMargin + s.boxAlong, 0, m.endMargin, filletDeep));
    if (s.joinStart && m.joinFillet)
      out.push(rect(0, m.farV, m.half + R, R + m.half));
    if (s.joinEnd && m.joinFillet)
      out.push(rect(m.alongLength - m.half - R, m.farV, m.half + R, R + m.half));
    if (back > 0)
      out.push(rect(0, -back, m.alongLength, back));
    return out.filter(r => r.width > 0 && r.height > 0);
  }
}
