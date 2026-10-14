pragma Singleton
import QtQuick

// What a surface growing out of a screen edge touches, and every rule that
// follows from it, for each kind of surface alike: bar popouts, edge popouts
// (OSDs, floating edge menus, the attached launcher), docks and submenus.
// One answer per intersection, so if a corner fillets (or doesn't) for one
// of them it does for all (tests/tst_SurfaceContext.qml). Pure: callers pass
// the bars (Bar.enrichBarConfig entries) and the shape metrics.
//
// EdgeAttach places the box along its edge; this decides what it's given:
// which ends may join, which are walls, the room kept at each, whether it's
// detached, and how it casts its shadow.
QtObject {
  id: root

  // What a surface's end meets on the perpendicular edge there. `p`:
  //   border (the screen border is on), bar (the enriched bar on that edge,
  //   or null), barShowing (it's mapped: a pill bar hides under fullscreen
  //   windows; default true), menuZone (an integrated menu's strip there)
  // Returns { kind, joinable, island }, kind one of:
  //   "border"      the border's stroke (a solid bar under it too)
  //   "bare"        a bare screen edge, run straight off
  //   "solidStroke" a solid bar's own inner stroke (border off)
  //   "pillBar"     a pill bar's far side (PillBarJoin)
  //   "wall"        nothing to join: another bar's edge or a menu's strip,
  //                 where the windows start
  function endKind(p) {
    const bar = p.bar ?? null;
    const island = !!bar?.island;
    const wall = {
      "kind": "wall",
      "joinable": false,
      "island": island
    };
    if ((p.menuZone ?? 0) > 0)
      return wall;
    if (!bar)
      return {
        "kind": p.border ? "border" : "bare",
        "joinable": true,
        "island": false
      };
    if (bar.solid)
      return {
        "kind": p.border ? "border" : "solidStroke",
        "joinable": true,
        "island": false
      };
    if (bar.pills && (p.barShowing ?? true))
      return {
        "kind": "pillBar",
        "joinable": true,
        "island": false
      };
    return wall;
  }

  // Room a side wall's fillet takes along the edge: none on a bare screen
  // edge, which the surface runs straight off, else EdgeAttach's (none
  // with a radius too tight for one)
  function filletMargin(ownBare, stroke, radius) {
    return ownBare ? 0 : EdgeAttach.filletMargin(stroke, radius);
  }

  // The least room a box keeps from an end it doesn't join: its fillet's,
  // past the frame's rounded inner corner while the border is on, so the
  // fillet's arc starts where the corner's ends
  function endRoom(ownBare, border, stroke, radius) {
    return root.filletMargin(ownBare, stroke, radius) + (border && !ownBare ? radius : 0);
  }

  // Where a wall stands, from the perpendicular screen edge: where windows
  // start past what's there (its reserved space and gaps_out), no nearer
  // than its frame line (a bar reserving nothing)
  function wallLine(frameLine, reserved, gapsOut) {
    return Math.max(frameLine, reserved + gapsOut);
  }

  // Where a surface meeting a wall stops, its fillet included, from the
  // perpendicular screen edge: its box in line with the windows (`windows`,
  // wallLine), its fillet past that beside the stroke it stands on, pushed
  // in only as far as that fillet needs to clear the frame's rounded inner
  // corner (`corner`, BarManager.cornerLine; `room`, endRoom: the fillet's
  // `fm` and the corner's arc)
  function wallAt(windows, corner, fm, room) {
    return Math.max(windows - fm, corner + room - fm);
  }

  // One end of a surface, from what it meets (endKind) and the surface.
  // `s`: held (held off its edge, or over a fullscreen window), detached
  //   (a box of its own), ownIsland (growing out of a floating bar's
  //   islands, whose ends never join: a side runs flush into the island),
  //   ownEndHeld (its bar's end is held clear of the bar there, so its
  //   islands already keep to the windows: no wall), stroke (borderWidth)
  // Returns { kind, joins (may join it: EdgeAttach.joins' startOk/endOk),
  //   strokeInset (how far its window reaches onto the stroke there, for a
  //   joined end to sit on its outer edge), straight (a joined end runs
  //   straight off it rather than curving in with a fillet; a pill bar's
  //   end decides that itself, PillBarJoin.filleted), wall (its box stops
  //   in line with the windows there, its fillet past them, clear of the
  //   frame's corner: wallAt), sink (where the
  //   stroke a joined end covers is left open: "border", "solidBar" or
  //   "pillBar"; null for none) }
  function end(e, s) {
    const joins = e.joinable && !s.held && !s.detached && !s.ownIsland;
    return {
      "kind": e.kind,
      "joins": joins,
      "strokeInset": joins && e.kind !== "bare" ? s.stroke : 0,
      "straight": e.kind === "bare",
      "wall": !s.held && e.kind === "wall" && !s.ownEndHeld,
      "island": e.island,
      "sink": !joins ? null : e.kind === "border" ? "border" : e.kind === "solidStroke" ? "solidBar" : e.kind === "pillBar" ? "pillBar" : null
    };
  }

  // A box of its own rather than grown out of what's on its edge: held
  // off it, past a transparent bar, or on a floating bar showing no
  // islands (EdgeAttach.place's mode "plain" there)
  function detached(held, bar, mode) {
    if (held)
      return true;
    if (!bar || bar.solid)
      return false;
    return bar.background === "transparent" || (!!bar.island && mode === "plain");
  }

  // Whether a bar's shadow falls away from its edge rather than spreading
  // evenly: pills joined to the border spread as the border's does (one
  // shifted along that stroke would cover it), anything else falls
  function barShadowFalls(bar, border) {
    return !bar.pills || !border;
  }

  // How a surface casts its shadow: { look ("style": BarStyle's, "bar":
  // its bar's), edge (a Bar.Location it falls away from), falls }. It
  // takes it from what it grows out of, so joined shapes cast one shadow
  // (BlurBacking groups them by look and fall) running unbroken round them:
  //   a submenu, its parent's (`parent`, as returned here)
  //   a detached box falls away from its edge, in BarStyle's look
  //   out of a bar (its pills, islands, outer edge, or a solid bar's own
  //   stroke with the border off), the bar's look and fall
  //   out of the border's stroke, BarStyle's, spreading evenly; off a bare
  //   edge, falling
  // `s`: { edge, detached, border, bar (enriched, or null), onBar (it grows
  //   out of the bar: onPill, merged, or bar.innerStroke), parent }
  function shadow(s) {
    if (s.parent)
      return s.parent;
    if (s.detached)
      return {
        "look": "style",
        "edge": s.edge,
        "falls": true
      };
    if (s.bar && s.onBar)
      return {
        "look": "bar",
        "edge": s.edge,
        "falls": root.barShadowFalls(s.bar, s.border)
      };
    return {
      "look": "style",
      "edge": s.edge,
      "falls": !s.border
    };
  }

  // A stretch of a stroke left open ({ start, end, startFillet?,
  // endFillet? }), on whole pixels so neither the stroke nor a fillet's cap
  // half-covers one; `startFillet`/`endFillet` (> 0) the radius a surface
  // curves into the stroke with at that end, no more than the stretch
  function opening(start, end, startFillet, endFillet) {
    const s = Math.ceil(start), e = Math.floor(end);
    const o = {
      "start": s,
      "end": Math.max(s, e)
    };
    const room = o.end - o.start;
    if ((startFillet ?? 0) > 0)
      o.startFillet = Math.max(0, Math.min(startFillet, room));
    if ((endFillet ?? 0) > 0)
      o.endFillet = Math.max(0, Math.min(endFillet, room - (o.startFillet ?? 0)));
    return o;
  }

  // ---- One surface on an edge, whoever hosts it ----
  // Everything below is in screen px along the edge (0 at its start: the
  // top or left screen edge), across it in px from the screen edge, so a
  // bar popout, an edge popout and a dock at the same place get the same
  // answer. EdgePlacement gathers the inputs and converts to its host's
  // window.

  /**
   * What a surface's ends meet and the room it has along its edge, before
   * its box is known. `p`:
   *   span (the edge's length), border (the screen border is on), bareEdge
   *     (its own edge is bare), gap (connector gap), stroke, radius
   *   held, gaps ({ start, end } from the frame lines, held only)
   *   bar (the enriched bar it follows, or null), barStart, barLength
   *     (where that bar's window lies along the edge), islandFrom,
   *     islandTo (where its islands may reach)
   *   start, end: per perpendicular side { kind (endKind), frame (its
   *     frame line: what an unjoined end measures its room from), reserved
   *     (where windows start, before gaps_out), gapsOut, corner (where the
   *     frame's rounded inner corner lies, BarManager.cornerLine),
   *     barHeld (the followed bar's end there is held clear of a bar) },
   *     each in px from that side's own screen edge
   * Returns { startEnd, endEnd (end(), their strokeInset widened to reach an
   *   unjoined end's fillet where it starts short of `reserved`), lo, hi
   *   (where an unjoined box may
   *   reach, fillets in), joinFrom, joinTo (where a joined end sits),
   *   strokeFrom, strokeTo (the perpendicular strokes' outer edges, or a
   *   floating bar's island reach), wallFrom, wallTo (where a surface
   *   meeting a wall stops, its fillet included: wallAt; or undefined),
   *   pillFrom, pillTo, islandFrom, islandTo }
   */
  function frame(p) {
    const bar = p.bar ?? null;
    const island = !!bar?.island;
    const pillBar = !!bar && (!!bar.pills || island);
    const fm = root.filletMargin(p.bareEdge, p.stroke, p.radius);
    const room = root.endRoom(p.bareEdge, p.border, p.stroke, p.radius);
    // Along the edge from its start: a side's distance from its own edge
    const at = (side, d) => side === "start" ? d : p.span - d;
    const sign = side => side === "start" ? 1 : -1;
    const sides = {};
    for (const side of ["start", "end"]) {
      const q = p[side];
      const e = root.end(q.kind, {
        "held": p.held,
        "detached": !!bar && !bar.solid && !pillBar,
        "ownIsland": island,
        "ownEndHeld": island && !!q.barHeld,
        "stroke": p.stroke
      });
      // Unjoined: held, its gap past the frame line (no nearer than where
      // windows start); at a wall, in line with the windows past it, its
      // fillet clear of the frame's corner (wallAt); on a floating bar, its
      // islands' reach; else the frame's corner room
      let limit, wall;
      if (p.held)
        limit = at(side, Math.max(q.reserved, q.frame + (p.gaps?.[side] ?? 0)));
      else if (e.wall) {
        wall = at(side, root.wallAt(root.wallLine(q.frame, q.reserved, q.gapsOut), q.corner ?? 0, fm, room));
        limit = wall + sign(side) * fm;
      } else if (island)
        limit = (side === "start" ? p.islandFrom : p.islandTo) + sign(side) * fm;
      else
        limit = at(side, q.frame) + sign(side) * room;
      const stroke = island ? (side === "start" ? p.islandFrom : p.islandTo) : at(side, q.frame - (q.kind.kind === "bare" ? 0 : p.stroke));
      const unjoined = bar ? (side === "start" ? p.barStart : p.barStart + p.barLength) : at(side, q.frame);
      // Its window reaches back past where windows start as far as its
      // surface may: a joined end onto the stroke it sits on, an unjoined
      // one to where its fillet starts (a wall's past the windows' line,
      // over what's reserved there), or that part of it is clipped
      const from = p.held ? limit : limit - sign(side) * fm;
      const reach = Math.ceil(sign(side) * (at(side, q.reserved) - from));
      sides[side] = {
        "end": Object.assign({}, e, {
          "strokeInset": Math.max(e.strokeInset, reach)
        }),
        "limit": limit,
        "stroke": stroke,
        "join": e.joins ? stroke : unjoined,
        "wall": wall
      };
    }
    return {
      "startEnd": sides.start.end,
      "endEnd": sides.end.end,
      "lo": sides.start.limit,
      "hi": sides.end.limit,
      "joinFrom": sides.start.join,
      "joinTo": sides.end.join,
      "strokeFrom": sides.start.stroke,
      "strokeTo": sides.end.stroke,
      "wallFrom": sides.start.wall,
      "wallTo": sides.end.wall,
      "pillFrom": bar ? p.barStart : sides.start.join,
      "pillTo": bar ? p.barStart + p.barLength : sides.end.join,
      "islandFrom": p.islandFrom,
      "islandTo": p.islandTo
    };
  }

  // Which ends a box wanting `start` to `start + length` joins, given its
  // frame (EdgeAttach.joins)
  function joinsOf(f, start, length, gap) {
    return EdgeAttach.joins(start, length, f.lo, f.hi, gap, f.startEnd.joins, f.endEnd.joins);
  }

  /**
   * The box placed in its frame (`f`, frame()) and all that follows from
   * where it lands. `p`, as frame()'s, and:
   *   pills (the followed bar's pills or islands, along the edge), centre,
   *     aligned, length (the content's), joinStart, joinEnd (joinsOf)
   *   frameLine (across: the inner side of what's on its own edge),
   *     reserved (where windows start across it), detachedPush
   *     (Bar.detachedPush for the followed bar), ownBar (whatever bar is on
   *     its edge, for the shadow), across (held: the gap from the frame
   *     line across the edge)
   * Returns EdgeAttach.place's result and: merged, onPill, detached,
   *   straight, backfill, attachClearance, attachAt (across, from the
   *   screen edge), attachFromBar (the same from the followed bar's outer
   *   edge), barOuter, ownSink, shadow, stretchFrom, stretchTo (where a
   *   joined submenu's reach along its pill stays)
   */
  function layout(f, p) {
    const bar = p.bar ?? null;
    const island = !!bar?.island;
    const pillBar = !!bar && (!!bar.pills || island);
    const place = EdgeAttach.place({
      "pills": p.pills ?? [],
      "pillBar": !!bar?.pills,
      "island": island,
      "merge": bar?.pillMerge ?? 0,
      "centre": p.centre,
      "aligned": p.aligned,
      "length": p.length,
      "joinStart": p.joinStart,
      "joinEnd": p.joinEnd,
      "joinFrom": f.joinFrom,
      "joinTo": f.joinTo,
      "lo": f.lo,
      "hi": f.hi,
      "wallFrom": f.wallFrom,
      "wallTo": f.wallTo,
      "islandFrom": f.islandFrom,
      "islandTo": f.islandTo,
      "straight": p.bareEdge,
      "straightMerged": !p.border,
      "pillGrows": true,
      "pillJoins": true,
      "joinableStart": f.startEnd.joins,
      "joinableEnd": f.endEnd.joins,
      "pillFrom": f.pillFrom,
      "pillTo": f.pillTo,
      "gap": p.gap,
      "stroke": p.stroke,
      "radius": p.radius
    });
    const merged = place.mode === "merged";
    const onPill = place.mode === "pill" || place.mode === "island";
    const detached = root.detached(p.held, bar, place.mode);
    const pillFoot = pillBar ? (island ? bar.extent : bar.pillDepth) - p.stroke : 0;
    const barOuter = bar ? p.frameLine - bar.extent : 0;
    // Where the attach edge goes, from the followed bar's outer edge: that
    // edge when merged, a pill's or island's far stroke, a solid bar's own
    // inner stroke, or a transparent bar's inner edge (moved so its box is
    // in line with the windows, Bar.detachedPush)
    const attachFromBar = !bar ? 0 : merged ? 0 : onPill ? pillFoot : bar.extent - (bar.innerStroke ? p.stroke : 0) + (p.detachedPush ?? 0);
    // Held, a connector gap short of where the box goes; following a bar,
    // as that meets it; else on the stroke of what reserves the edge
    const attachAt = p.held ? p.frameLine + (p.across ?? 0) - p.gap / 2 : bar ? barOuter + attachFromBar : p.reserved - (p.bareEdge ? 0 : p.stroke);
    // The stroke it stands on along its own edge: the border's, or with
    // the border off a solid bar's own (not a pill's or island's: the bar
    // opens that itself; nor a bare edge's)
    let ownSink;
    if (detached || onPill || (bar && !bar.solid && !merged) || p.bareEdge)
      ownSink = null;
    else if (merged)
      ownSink = p.border ? "border" : null;
    else
      ownSink = p.border ? "border" : "solidBar";
    const ownBar = p.ownBar ?? null;
    return Object.assign({}, place, {
      "merged": merged,
      "onPill": onPill,
      "detached": detached,
      "straight": merged ? !p.border : place.mode === "plain" && p.bareEdge,
      "backfill": !detached && onPill ? 1 : 0,
      "attachClearance": merged ? pillFoot : 0,
      "attachAt": attachAt,
      "attachFromBar": attachFromBar,
      "barOuter": barOuter,
      "ownSink": ownSink,
      "shadow": root.shadow({
        "edge": p.edge,
        "detached": detached,
        "border": p.border,
        "bar": ownBar,
        "onBar": !p.held && (onPill || merged || (ownBar?.innerStroke ?? false))
      }),
      // A joined submenu's reach along the pill it stands on stays between
      // the strokes at the edge's ends
      "stretchFrom": f.strokeFrom,
      "stretchTo": f.strokeTo
    });
  }
}
