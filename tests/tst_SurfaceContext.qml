import QtQuick
import QtTest
import qs.components.methods

TestCase {
  name: "SurfaceContext"

  // An enriched bar, as far as SurfaceContext reads it
  function bar(background) {
    return {
      "background": background,
      "solid": background === "solid",
      "pills": background === "pills",
      "island": background === "floating" || background === "floatingPills"
    };
  }

  readonly property var surface: ({
      "held": false,
      "detached": false,
      "ownIsland": false,
      "ownEndHeld": false,
      "stroke": 2
    })

  // Every perpendicular edge, border on and off: what an end meets, and
  // what that makes it for an attached surface. One row per intersection,
  // the same for bar popouts, edge popouts, docks and submenus alike.
  function test_endKinds_data() {
    const rows = [];
    const expect = {
      "none": ["border", "bare"],
      "solid": ["border", "solidStroke"],
      "pills": ["pillBar", "pillBar"],
      "transparent": ["wall", "wall"],
      "floating": ["wall", "wall"],
      "floatingPills": ["wall", "wall"]
    };
    for (const background of Object.keys(expect)) {
      [true, false].forEach((border, i) => rows.push({
          "tag": `${background}, border ${border ? "on" : "off"}`,
          "bar": background === "none" ? null : bar(background),
          "border": border,
          "kind": expect[background][i]
        }));
    }
    return rows;
  }
  function test_endKinds(data) {
    const e = SurfaceContext.endKind({
      "border": data.border,
      "bar": data.bar
    });
    compare(e.kind, data.kind);
    compare(e.joinable, data.kind !== "wall");
    const end = SurfaceContext.end(e, surface);
    compare(end.joins, data.kind !== "wall");
    compare(end.wall, data.kind === "wall");
    compare(end.straight, data.kind === "bare");
    compare(end.strokeInset, data.kind === "wall" || data.kind === "bare" ? 0 : 2);
    compare(end.sink, {
      "border": "border",
      "bare": null,
      "solidStroke": "solidBar",
      "pillBar": "pillBar",
      "wall": null
    }[data.kind]);
  }

  function test_menuStripIsAWall() {
    compare(SurfaceContext.endKind({
      "border": true,
      "bar": null,
      "menuZone": 40
    }).kind, "wall");
  }

  function test_hiddenPillBarIsAWall() {
    compare(SurfaceContext.endKind({
      "border": true,
      "bar": bar("pills"),
      "barShowing": false
    }).kind, "wall");
  }

  // Held, detached or on an island, no end joins (each host once gated
  // this differently); only a held surface has no walls (it keeps its
  // gaps), nor an island at a bar its own end is held clear of
  function test_nothingJoins_data() {
    return [
      {
        "tag": "held",
        "s": {
          "held": true
        },
        "wall": false
      },
      {
        "tag": "detached",
        "s": {
          "detached": true
        },
        "wall": true
      },
      {
        "tag": "island",
        "s": {
          "ownIsland": true
        },
        "wall": true
      },
      {
        "tag": "island, end held",
        "s": {
          "ownIsland": true,
          "ownEndHeld": true
        },
        "wall": false
      }
    ];
  }
  function test_nothingJoins(data) {
    const s = Object.assign({}, surface, data.s);
    for (const background of [null, "solid", "pills"]) {
      const end = SurfaceContext.end(SurfaceContext.endKind({
        "border": true,
        "bar": background ? bar(background) : null
      }), s);
      verify(!end.joins, `${background} joins`);
      compare(end.strokeInset, 0);
      compare(end.sink, null);
    }
    const wall = SurfaceContext.end(SurfaceContext.endKind({
      "border": true,
      "bar": bar("transparent")
    }), s);
    compare(wall.wall, data.wall);
  }

  function test_margins() {
    // gap 48, stroke 2, radius 24
    compare(SurfaceContext.filletMargin(false, 48, 2, 24), 46);
    compare(SurfaceContext.filletMargin(true, 48, 2, 24), 0);
    compare(SurfaceContext.filletMargin(false, 48, 4, 1), 0);
    compare(SurfaceContext.endRoom(false, true, 48, 2, 24), 70);
    compare(SurfaceContext.endRoom(false, false, 48, 2, 24), 46);
    compare(SurfaceContext.endRoom(true, false, 48, 2, 24), 0);
    compare(SurfaceContext.wallLine(30, 40, 10), 50);
    compare(SurfaceContext.wallLine(60, 40, 10), 60);
  }

  function test_detached_data() {
    return [
      {
        "tag": "held",
        "held": true,
        "bar": "solid",
        "mode": "plain",
        "detached": true
      },
      {
        "tag": "no bar",
        "held": false,
        "bar": null,
        "mode": "plain",
        "detached": false
      },
      {
        "tag": "solid",
        "held": false,
        "bar": "solid",
        "mode": "plain",
        "detached": false
      },
      {
        "tag": "transparent",
        "held": false,
        "bar": "transparent",
        "mode": "plain",
        "detached": true
      },
      {
        "tag": "pills",
        "held": false,
        "bar": "pills",
        "mode": "pill",
        "detached": false
      },
      {
        "tag": "pills, none showing",
        "held": false,
        "bar": "pills",
        "mode": "merged",
        "detached": false
      },
      {
        "tag": "island",
        "held": false,
        "bar": "floating",
        "mode": "island",
        "detached": false
      },
      {
        "tag": "floating, no islands",
        "held": false,
        "bar": "floating",
        "mode": "plain",
        "detached": true
      }
    ];
  }
  function test_detached(data) {
    compare(SurfaceContext.detached(data.held, data.bar ? bar(data.bar) : null, data.mode), data.detached);
  }

  // A surface's shadow is what it grows out of: joined shapes then land in
  // one group and cast one shadow round them
  function test_shadow_data() {
    return [
      {
        "tag": "border",
        "s": {
          "border": true,
          "bar": null,
          "onBar": false
        },
        "look": "style",
        "falls": false
      },
      {
        "tag": "bare edge",
        "s": {
          "border": false,
          "bar": null,
          "onBar": false
        },
        "look": "style",
        "falls": true
      },
      {
        "tag": "solid bar under the border",
        "s": {
          "border": true,
          "bar": bar("solid"),
          "onBar": false
        },
        "look": "style",
        "falls": false
      },
      {
        "tag": "pills, border on",
        "s": {
          "border": true,
          "bar": bar("pills"),
          "onBar": true
        },
        "look": "bar",
        "falls": false
      },
      {
        "tag": "pills, border off",
        "s": {
          "border": false,
          "bar": bar("pills"),
          "onBar": true
        },
        "look": "bar",
        "falls": true
      },
      {
        "tag": "island, border on",
        "s": {
          "border": true,
          "bar": bar("floating"),
          "onBar": true
        },
        "look": "bar",
        "falls": true
      },
      {
        "tag": "detached",
        "s": {
          "border": true,
          "bar": bar("transparent"),
          "onBar": false,
          "detached": true
        },
        "look": "style",
        "falls": true
      }
    ];
  }
  function test_shadow(data) {
    const s = SurfaceContext.shadow(Object.assign({
      "edge": 0,
      "detached": false
    }, data.s));
    compare(s.look, data.look);
    compare(s.falls, data.falls);
    compare(s.edge, 0);
    // The bar's own pieces fall the same way
    if (data.look === "bar")
      compare(SurfaceContext.barShadowFalls(data.s.bar, data.s.border), data.falls);
  }

  function test_submenuTakesItsParentsShadow() {
    const parent = SurfaceContext.shadow({
      "edge": 0,
      "detached": false,
      "border": false,
      "bar": null,
      "onBar": false
    });
    compare(SurfaceContext.shadow({
      "edge": 2,
      "parent": parent
    }), parent);
  }

  function test_opening() {
    compare(SurfaceContext.opening(10.4, 50.6), {
      "start": 11,
      "end": 50
    });
    compare(SurfaceContext.opening(0, 10.5, 24, true), {
      "start": 0,
      "end": 10,
      "fillet": 10,
      "filletAtEnd": true
    });
    compare(SurfaceContext.opening(5.5, 5.2).end, 6);
  }

  // ---- frame() / layout(): one surface on an edge, any host ----

  // A 1000 px edge, border on (2 px stroke, radius 12, gap 24), the
  // perpendicular edges' inner sides 20 px in, windows starting there
  function side(kind, extra) {
    return Object.assign({
      "kind": SurfaceContext.endKind({
        "border": true,
        "bar": kind === "none" ? null : bar(kind)
      }),
      "frame": 20,
      "reserved": 20,
      "gapsOut": 10,
      "barHeld": false
    }, extra ?? {});
  }
  function params(extra) {
    return Object.assign({
      "edge": 0,
      "span": 1000,
      "border": true,
      "bareEdge": false,
      "gap": 24,
      "stroke": 2,
      "radius": 12,
      "held": false,
      "gaps": null,
      "bar": null,
      "barStart": 0,
      "barLength": 1000,
      "islandFrom": 0,
      "islandTo": 1000,
      "start": side("none"),
      "end": side("none")
    }, extra ?? {});
  }

  function test_frame_border() {
    const f = SurfaceContext.frame(params());
    const room = SurfaceContext.endRoom(false, true, 24, 2, 12);
    compare(f.lo, 20 + room);
    compare(f.hi, 1000 - 20 - room);
    // Joined ends sit on the strokes' outer edges
    compare(f.joinFrom, 18);
    compare(f.joinTo, 982);
    verify(f.startEnd.joins && f.endEnd.joins);
    compare(f.wallFrom, undefined);
  }

  function test_frame_bare_edges_join_flush() {
    const bare = s => Object.assign(side("none"), {
        "kind": SurfaceContext.endKind({
          "border": false,
          "bar": null
        })
      });
    const f = SurfaceContext.frame(params({
      "border": false,
      "start": bare(),
      "end": bare()
    }));
    compare(f.joinFrom, 20);
    compare(f.joinTo, 980);
    verify(f.startEnd.straight);
  }

  function test_frame_wall_where_windows_start() {
    // A transparent bar on the start side: a wall at its reserved line
    // plus gaps_out, never nearer than its frame line
    const f = SurfaceContext.frame(params({
      "start": side("transparent", {
        "frame": 40,
        "reserved": 34
      })
    }));
    verify(!f.startEnd.joins);
    compare(f.wallFrom, 44);
    compare(f.lo, 44);
  }

  function test_frame_held_keeps_its_gaps() {
    const f = SurfaceContext.frame(params({
      "held": true,
      "gaps": {
        "start": 8,
        "end": 0
      },
      "end": side("none", {
        "reserved": 30
      })
    }));
    verify(!f.startEnd.joins && !f.endEnd.joins);
    compare(f.lo, 28);
    // No nearer than where windows start
    compare(f.hi, 970);
  }

  function test_frame_island_bar() {
    const floating = Object.assign(bar("floating"), {
      "extent": 40,
      "pillDepth": 30
    });
    const f = SurfaceContext.frame(params({
      "bar": floating,
      "islandFrom": 30,
      "islandTo": 970,
      // Its end held clear of a bar there: its islands already keep to
      // the windows, so no wall
      "start": side("transparent", {
        "barHeld": true
      })
    }));
    verify(!f.startEnd.joins && !f.endEnd.joins);
    compare(f.wallFrom, undefined);
    const fm = SurfaceContext.filletMargin(false, 24, 2, 12);
    compare(f.lo, 30 + fm);
    compare(f.hi, 970 - fm);
    compare(f.strokeFrom, 30);
  }

  function test_layout_attach_across() {
    const solid = Object.assign(bar("solid"), {
      "extent": 40,
      "innerStroke": true
    });
    const base = params();
    const f = SurfaceContext.frame(base);
    const at = extra => SurfaceContext.layout(f, Object.assign({}, base, {
        "centre": 500,
        "aligned": 450,
        "length": 100,
        "joinStart": false,
        "joinEnd": false,
        "frameLine": 40,
        "reserved": 40
      }, extra));
    // On the stroke of what reserves the edge
    compare(at({}).attachAt, 38);
    compare(at({}).ownSink, "border");
    // Following a solid bar (border off): its own inner stroke
    const onSolid = at({
      "bar": solid,
      "border": false
    });
    compare(onSolid.attachFromBar, 38);
    compare(onSolid.attachAt, 38);
    compare(onSolid.ownSink, "solidBar");
    // Held: a connector gap short of its gap past the frame line
    compare(at({
      "held": true,
      "across": 10
    }).attachAt, 38);
    verify(at({
      "held": true,
      "across": 10
    }).detached);
  }
}
