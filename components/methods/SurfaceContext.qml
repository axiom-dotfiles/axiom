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

  // Whether an end of that kind is joined by a stroke of its own (the
  // border's, a solid bar's or a bare edge), not through a pill bar
  function strokeJoinable(kind) {
    return kind === "border" || kind === "bare" || kind === "solidStroke";
  }

  // Room a side wall's fillet takes along the edge: none on a bare screen
  // edge, which the surface runs straight off, nor with a radius too tight
  // for one (see SurfaceOutline's `sharp`)
  function filletMargin(ownBare, gap, stroke, radius) {
    return ownBare || radius < stroke / 2 ? 0 : Math.max(0, gap - stroke);
  }

  // The least room a box keeps from an end it doesn't join: its fillet's,
  // past the frame's rounded inner corner while the border is on (a
  // fillet's run along the stroke beside that arc draws a straight stub)
  function endRoom(ownBare, border, gap, stroke, radius) {
    return root.filletMargin(ownBare, gap, stroke, radius) + (border && !ownBare ? radius : 0);
  }

  // Where a wall stands, from the perpendicular screen edge: where windows
  // start past what's there (its reserved space and gaps_out), no nearer
  // than its frame line (a bar reserving nothing)
  function wallLine(frameLine, reserved, gapsOut) {
    return Math.max(frameLine, reserved + gapsOut);
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
  //   end decides that itself, PillBarJoin.filleted), wall (its walls stop
  //   where windows start there, its fillet inside them too), sink (where the
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

  // A stretch of a stroke left open ({ start, end, fillet?, filletAtEnd? }),
  // on whole pixels so neither the stroke nor the fillet's cap half-covers
  // one; `fillet` (> 0) the radius it curves in with at one end, no more
  // than the stretch
  function opening(start, end, fillet, filletAtEnd) {
    const s = Math.ceil(start), e = Math.floor(end);
    const o = {
      "start": s,
      "end": Math.max(s, e)
    };
    if ((fillet ?? 0) > 0) {
      o.fillet = Math.max(0, Math.min(fillet, o.end - o.start));
      o.filletAtEnd = !!filletAtEnd;
    }
    return o;
  }
}
