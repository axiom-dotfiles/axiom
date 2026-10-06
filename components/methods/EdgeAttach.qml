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
// - On a pill bar, a box within the pill under its centre stands on that
//   pill's far stroke, the pill stretched to carry its fillets; any other
//   grows from the bar's outer edge, the pills it reaches showing through
//   notches, its side walls standing on a pill that carries on past them
//   (reaching a little further onto one whose stroke they'd just miss).
// - On a floating bar it grows out of the island under its centre (else
//   the nearest one). A side whose fillet lands on the island (or on
//   neighbours a stretch comes within `merge` of) keeps it; any other
//   reaches to the island's end and runs flush into it, the island
//   stretched to the box where the box goes past it.
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
  //   straightMerged (likewise for one merged around pills)
  //   gap (connector gap), stroke, radius
  // Returns { mode: "plain" | "pill" | "merged" | "island", pill, start,
  //   end (the box), grow (the box past `length`), contentStart (where
  //   the content's `length` starts) and contentOffset (from the box's
  //   start), joinStart, joinEnd, flushStart, flushEnd, footStart, footEnd
  //   (a side wall stands on a pill), startMargin, endMargin (the
  //   surface's fillet room), surfaceStart, surfaceLength, mergedPills,
  //   stretch ({ index, start, end, squareStart, squareEnd } or null) }
  function place(s) {
    const pills = s.pills ?? [];
    const pill = pills.length > 0 ? root.pillAt(pills, s.centre, s.island) : null;
    if (s.island && pill !== null)
      return root._onIsland(s, pills, pill);
    const fm = root.filletMargin(s.gap, s.stroke, s.radius);
    const length = s.length;
    // On whole pixels: a fillet ending mid-pixel leaves a pale pixel in
    // the stroke it joins
    const lo = s.joinStart ? s.joinFrom : s.lo, hi = s.joinEnd ? s.joinTo : s.hi;
    const content = Math.round(Math.max(lo, Math.min(s.aligned, hi - length)));
    let start = s.joinStart ? s.joinFrom : content;
    let end = s.joinEnd ? s.joinTo : content + length;
    if (!s.island) {
      const snap = root._pillSnap(pills, start, end, s.gap, s.stroke, s.radius);
      start = Math.max(lo, start - snap.start);
      end = Math.min(hi, end + snap.end);
    }
    // A pill bar showing no pills still grows from its outer edge
    const pillBar = !s.island && (s.pillBar ?? pills.length > 0);
    const within = p => p !== null && start >= p.start && end <= p.start + p.length;
    const mode = !pillBar ? "plain" : within(pill) ? "pill" : "merged";
    const merged = mode === "merged";
    const r = s.radius;
    const footStart = merged && !s.joinStart && pills.some(p => p.start <= start - r && p.start + p.length >= start);
    const footEnd = merged && !s.joinEnd && pills.some(p => p.start <= end && p.start + p.length >= end + r);
    const straight = mode === "plain" ? !!s.straight : merged ? !!s.straightMerged : false;
    const startMargin = !s.joinStart && (!straight || footStart) ? fm : 0;
    const endMargin = !s.joinEnd && (!straight || footEnd) ? fm : 0;
    const surfaceStart = start - startMargin;
    const surfaceLength = startMargin + (end - start) + endMargin;
    let stretch = null;
    if (mode === "pill") {
      const from = pill.joinStart ? pill.start : Math.min(pill.start, surfaceStart - r);
      const to = pill.joinEnd ? pill.start + pill.length : Math.max(pill.start + pill.length, surfaceStart + surfaceLength + r);
      if (from !== pill.start || to !== pill.start + pill.length)
        stretch = {
          "index": pill.index,
          "start": from,
          "end": to,
          "squareStart": false,
          "squareEnd": false
        };
    }
    return {
      "mode": mode,
      "pill": mode === "pill" ? pill : null,
      "start": start,
      "end": end,
      "grow": end - start - length,
      "contentStart": content,
      "contentOffset": content - start,
      "joinStart": !!s.joinStart,
      "joinEnd": !!s.joinEnd,
      "flushStart": false,
      "flushEnd": false,
      "footStart": footStart,
      "footEnd": footEnd,
      "startMargin": startMargin,
      "endMargin": endMargin,
      "surfaceStart": surfaceStart,
      "surfaceLength": surfaceLength,
      "mergedPills": merged ? pills.filter(p => p.start < surfaceStart + surfaceLength && p.start + p.length > surfaceStart) : [],
      "stretch": stretch
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

  // A merged box whose side wall falls just short of a pill's stroke would
  // draw its wall and fillet a few pixels off that stroke, a double line
  // with a sliver between. How much further each side (at most a connector
  // gap) reaches so its wall lies on the stroke and stands on the pill,
  // { start, end }; none for a box within a pill, or no pill that close.
  function _pillSnap(pills, start, end, gap, stroke, radius) {
    const snap = {
      "start": 0,
      "end": 0
    };
    if (pills.some(p => p.start <= start && end <= p.start + p.length))
      return snap;
    for (const p of pills) {
      const toEnd = p.start + stroke - end;
      if (snap.end === 0 && toEnd > 0 && toEnd <= gap && p.start + p.length >= end + toEnd + radius)
        snap.end = toEnd;
      const toStart = start - (p.start + p.length - stroke);
      if (snap.start === 0 && toStart > 0 && toStart <= gap && p.start <= start - toStart - radius)
        snap.start = toStart;
    }
    return snap;
  }

  // How far the island `own` reaches toward `target` (before it when
  // `before`): its own end, or that of the neighbours a stretch to there
  // would come within `merge` of, which then draw as one with it
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

  function _onIsland(s, pills, own) {
    const fm = root.filletMargin(s.gap, s.stroke, s.radius);
    const length = s.length, r = s.radius;
    // Room past the box for a fillet: its margin, and the island's rounded
    // corner beyond, which a fillet can't land on
    const need = fm + r;
    const content = Math.round(Math.max(s.islandFrom, Math.min(s.aligned, s.islandTo - length)));
    const from = root._islandReach(pills, own, content - need, true, s.merge);
    const to = root._islandReach(pills, own, content + length + need, false, s.merge);
    // A side whose fillet doesn't fit reaches to the island's end, or
    // past it the island stretching to it, running flush into it
    const flushStart = content - need < from, flushEnd = content + length + need > to;
    const start = flushStart ? Math.min(content, from) : content;
    const end = flushEnd ? Math.max(content + length, to) : content + length;
    const startMargin = flushStart ? 0 : fm, endMargin = flushEnd ? 0 : fm;
    const surfaceStart = start - startMargin;
    const surfaceLength = startMargin + (end - start) + endMargin;
    // To a flush side's end, squaring the island's corner there, else far
    // enough for the fillet
    const stretchFrom = flushStart ? start : Math.min(own.start, surfaceStart - r);
    const stretchTo = flushEnd ? end : Math.max(own.start + own.length, surfaceStart + surfaceLength + r);
    const stretched = stretchFrom !== own.start || stretchTo !== own.start + own.length || flushStart || flushEnd;
    return {
      "mode": "island",
      "pill": own,
      "start": start,
      "end": end,
      "grow": end - start - length,
      "contentStart": content,
      "contentOffset": content - start,
      "joinStart": false,
      "joinEnd": false,
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
