pragma Singleton
import QtQuick

// Where a box that grows out of a screen edge goes along it: bar popouts,
// edge popouts (the launcher, OSDs, floating edge menus) and anything else
// drawn with AttachedSurface. One set of rules, so they all meet the frame,
// a bar's pills and a floating bar's islands the same way.
//
// Everything is along the edge in one coordinate system of the caller's
// (a bar window's, an edge popout's), and lengths are in px. No files,
// services or config: the caller passes the shape metrics.
//
// The content always sits where it wants (the caller's `aligned` start),
// moved only to stay within reach: the box grows around it to meet what
// it attaches to, rather than the content moving to make the box fit.
//
// - A box whose fillet would come within a connector gap of a
//   perpendicular edge it can join (the border, a solid bar) joins it
//   instead (`joins`): the box reaches to that stroke, flush on it.
// - On a pill bar or a floating bar it grows out of the pill (or island)
//   under its centre, else the nearest one. A side whose fillet lands on
//   it (or on neighbours a stretch comes within `merge` of) keeps it; any
//   other reaches to its end and runs flush into it, the pill stretched to
//   the box where the box goes past it. Where that end is a pill joining
//   the perpendicular edge, the box joins that edge too. A pill bar
//   showing no pills has nothing to grow out of: the box grows from its
//   outer edge (`merged`).
QtObject {
  id: root

  // Room a side wall's fillet takes along the edge (0 when the radius is
  // too tight for one, see AttachedSurface._sharp)
  function filletMargin(gap, stroke, radius) {
    return radius < stroke / 2 ? 0 : Math.max(0, gap - stroke);
  }

  // Whether a box wanting `start` to `start + length` joins the
  // perpendicular edges: when it would be pushed back from one, or leave
  // less than a connector gap between its fillet and it. `lo`/`hi` are the
  // nearest and furthest its box may reach unjoined (its fillets' room
  // included); `length` Infinity (content that fills any room) joins both.
  function joins(start, length, lo, hi, gap, startOk, endOk) {
    const endless = !isFinite(length);
    return {
      "joinStart": !!startOk && (endless || start < lo + gap),
      "joinEnd": !!endOk && (endless || start + length > hi - gap)
    };
  }

  // The pill (or island) a box centred at `centre` belongs to, with its
  // index: the one under the centre, or for an island the nearest
  function pillAt(pills, centre, island) {
    let best = -1, bestDistance = Infinity;
    pills.forEach((p, i) => {
      const distance = Math.max(0, p.start - centre, centre - (p.start + p.length));
      if (distance < bestDistance) {
        best = i;
        bestDistance = distance;
      }
    });
    if (best < 0 || (bestDistance > 0 && !island))
      return null;
    return Object.assign({
      "index": best
    }, pills[best]);
  }

  // The box's place along the edge. `s`:
  //   pills [{ start, length, joinStart, joinEnd }], pillBar (on a pill
  //     bar, even with none showing; else whether there are pills), island
  //     (they're a floating bar's islands), merge (pillMerge), centre
  //     (picks the pill)
  //   aligned (where the content's box would start), length (its length)
  //   joinStart, joinEnd (from `joins`), joinFrom, joinTo (where joined
  //     ends sit: the perpendicular strokes' outer edges)
  //   lo, hi (the range an unjoined box keeps within, fillets' room in)
  //   islandFrom, islandTo (where islands may reach)
  //   straight (a plain box's attach edge is a bare screen edge),
  //   straightMerged (likewise for one grown from a pill bar's outer edge)
  //   gap (connector gap), stroke, radius
  // Returns { mode: "plain" | "pill" | "island" | "merged", pill, start,
  //   end (the box), grow (the box past `length`), contentStart (where
  //   the content's `length` starts) and contentOffset (from the box's
  //   start), joinStart, joinEnd, flushStart, flushEnd, footStart, footEnd
  //   (a side wall stands on a pill; none now pills stretch instead),
  //   startMargin, endMargin (the surface's fillet room), surfaceStart,
  //   surfaceLength, mergedPills (none, likewise), stretch ({ index,
  //   start, end, squareStart, squareEnd } or null) }
  function place(s) {
    const pills = s.pills ?? [];
    // A pill bar showing no pills still grows from its outer edge
    const pillBar = !s.island && (s.pillBar ?? pills.length > 0);
    const pill = pills.length > 0 && (s.island || pillBar) ? root.pillAt(pills, s.centre, true) : null;
    if (pill !== null)
      return root._onPill(s, pills, pill, !s.island);
    const fm = root.filletMargin(s.gap, s.stroke, s.radius);
    const length = s.length;
    // On whole pixels: a fillet ending mid-pixel leaves a pale pixel in
    // the stroke it joins
    const lo = s.joinStart ? s.joinFrom : s.lo, hi = s.joinEnd ? s.joinTo : s.hi;
    const content = Math.round(Math.max(lo, Math.min(s.aligned, hi - length)));
    const start = s.joinStart ? s.joinFrom : content;
    const end = s.joinEnd ? s.joinTo : content + length;
    const mode = pillBar ? "merged" : "plain";
    const straight = pillBar ? !!s.straightMerged : !!s.straight;
    const startMargin = !s.joinStart && !straight ? fm : 0;
    const endMargin = !s.joinEnd && !straight ? fm : 0;
    return {
      "mode": mode,
      "pill": null,
      "start": start,
      "end": end,
      "grow": end - start - length,
      "contentStart": content,
      "contentOffset": content - start,
      "joinStart": !!s.joinStart,
      "joinEnd": !!s.joinEnd,
      "flushStart": false,
      "flushEnd": false,
      "footStart": false,
      "footEnd": false,
      "startMargin": startMargin,
      "endMargin": endMargin,
      "surfaceStart": start - startMargin,
      "surfaceLength": startMargin + (end - start) + endMargin,
      "mergedPills": [],
      "stretch": null
    };
  }

  // The notches a merged box leaves for `pills` to show through, from the
  // surface's start (`from`, `length` along): each pill's interior, `inset`
  // (its stroke and a pixel) inside its free ends, rounded where those fall
  // within the surface
  function notches(pills, from, length, inset) {
    return pills.map(p => {
      const start = p.start + (p.joinStart ? 0 : inset);
      const end = p.start + p.length - (p.joinEnd ? 0 : inset);
      return {
        "start": start - from,
        "length": Math.max(0, end - start),
        "roundStart": !p.joinStart && start > from,
        "roundEnd": !p.joinEnd && end < from + length
      };
    });
  }

  // How far the pill (or island) `own` reaches toward `target` (before it
  // when `before`): its own end, or that of the neighbours a stretch to
  // there would come within `merge` of, which then draw as one with it
  // (BarLayout.stretchIslands)
  function _islandReach(pills, own, target, before, merge) {
    let reach = before ? own.start : own.start + own.length;
    const others = pills.filter(p => before ? p.start < own.start : p.start > own.start).sort((a, b) => before ? b.start - a.start : a.start - b.start);
    for (const p of others) {
      if ((before ? target - (p.start + p.length) : p.start - target) > merge)
        break;
      reach = before ? p.start : p.start + p.length;
    }
    return reach;
  }

  // Growing out of pill (or island) `own`; a pill bar's (`isPill`) pills
  // may join the perpendicular edges at the bar's ends
  function _onPill(s, pills, own, isPill) {
    const fm = root.filletMargin(s.gap, s.stroke, s.radius);
    const length = s.length, r = s.radius;
    // Room past the box for a fillet: its margin, and the pill's rounded
    // corner beyond, which a fillet can't land on
    const need = fm + r;
    // Within reach: a pill bar's frame, or where islands may go
    const lo = isPill ? s.joinFrom : s.islandFrom, hi = isPill ? s.joinTo : s.islandTo;
    const content = Math.round(Math.max(lo, Math.min(s.aligned, hi - length)));
    const from = root._islandReach(pills, own, content - need, true, s.merge);
    const to = root._islandReach(pills, own, content + length + need, false, s.merge);
    // A side whose fillet doesn't fit reaches to the pill's end, or past it
    // the pill stretching to it, running flush into it; or where that's a
    // pill joining the perpendicular edge, joining that edge too
    const short0 = content - need < from, short1 = content + length + need > to;
    const joinStart = isPill && short0 && pills.some(p => p.joinStart && p.start === from);
    const joinEnd = isPill && short1 && pills.some(p => p.joinEnd && p.start + p.length === to);
    const flushStart = short0 && !joinStart, flushEnd = short1 && !joinEnd;
    const start = joinStart ? s.joinFrom : flushStart ? Math.min(content, from) : content;
    const end = joinEnd ? s.joinTo : flushEnd ? Math.max(content + length, to) : content + length;
    const startMargin = short0 ? 0 : fm, endMargin = short1 ? 0 : fm;
    const surfaceStart = start - startMargin;
    const surfaceLength = startMargin + (end - start) + endMargin;
    // To a flush side's end, squaring the pill's corner there, else far
    // enough for the fillet; a joined pill already reaches its edge
    const stretchFrom = joinStart ? from : flushStart ? start : Math.min(own.start, surfaceStart - r);
    const stretchTo = joinEnd ? to : flushEnd ? end : Math.max(own.start + own.length, surfaceStart + surfaceLength + r);
    const stretched = stretchFrom !== own.start || stretchTo !== own.start + own.length || flushStart || flushEnd;
    return {
      "mode": isPill ? "pill" : "island",
      "pill": own,
      "start": start,
      "end": end,
      "grow": end - start - length,
      "contentStart": content,
      "contentOffset": content - start,
      "joinStart": joinStart,
      "joinEnd": joinEnd,
      "flushStart": flushStart,
      "flushEnd": flushEnd,
      "footStart": false,
      "footEnd": false,
      "startMargin": startMargin,
      "endMargin": endMargin,
      "surfaceStart": surfaceStart,
      "surfaceLength": surfaceLength,
      "mergedPills": [],
      "stretch": stretched ? {
        "index": own.index,
        "start": stretchFrom,
        "end": stretchTo,
        "squareStart": flushStart,
        "squareEnd": flushEnd
      } : null
    };
  }
}
