pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Shapes

import qs.config
import qs.components.reusable
import qs.components.methods

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
  // it continues (see SurfaceOutline._outline). Off where that stroke now carries on past
  // it (a tray submenu joined beside it, the pill or island stretched
  // under it): the wall stops at the attach edge, the backfill running on.
  property bool flushStartThrough: true
  property bool flushEndThrough: true
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
  // The blur window (BlurManager) draws this surface's fill and casts its
  // shadow (BlurShape.shadow): it draws its stroke and content only
  property bool backed: false
  // Casting its own shadow, in its own window
  readonly property bool _ownShadow: root.castShadow && !root.backed
  // A copy of a surface (AttachedSurfaceCopy): its fill alone, its stroke
  // in `mirrorStroke`
  property bool mirror: false
  property color mirrorStroke: "transparent"
  // (a copy is drawn opaque: the blur window applies the opacity to all
  // of them at once, so where they overlap they don't stack)
  readonly property color _fill: root.mirror ? root.fillColor : root.backed ? "transparent" : Appearance.fill(root.fillColor)
  readonly property color _stroke: root.mirror ? root.mirrorStroke : root.strokeColor
  // Rects (in this item's coordinates) where its outline is left open:
  // what's joined to it over them (a tray submenu on its side, a popout on
  // a pill's far stroke) carries on there, its fill no longer hiding it
  property var strokeHoles: []

  default property alias content: contentContainer.data
  // The content box, sliding with the surface: where things in the
  // content are within the box whether or not it's out yet
  readonly property Item contentBox: contentContainer

  // Along the attach edge, the part of what it attaches to that it covers,
  // from its start: what of it shows at that edge as it slides, the box
  // and as much of each fillet as has come out past the edge (the fillet
  // runs along the edge, then curves up into the wall). A stroke left open
  // under it (the border's, a pill's) opens only there, or a gap shows
  // past the fillets, or the stroke cuts across them.
  // How far it's behind that edge: slid, or moved by its host (a hiding
  // dock, `hiddenBehind`)
  property real hiddenBehind: 0
  // How far it has slid behind that edge (none once out)
  readonly property real slid: Math.abs(slideContainer.slideX) + Math.abs(slideContainer.slideY)
  readonly property real _hidden: root.slid + root.hiddenBehind
  // How far in from the surface's end the fillet shows at the edge, with
  // `hidden` of the surface still behind it (see SurfaceOutline._outline: a line along
  // the edge at v = half to sideU - R, an arc of radius R up to the wall)
  function _filletIn(margin, hidden) {
    if (margin <= 0)
      return 0;
    const R = filletRadius, h = half;
    // The stroke along the edge is a full stroke wide
    if (hidden <= strokeWidth)
      return 0;
    if (hidden >= h + R)
      return margin;
    const dv = h + R - hidden;
    return Math.min(margin, Math.max(0, margin + h - R + Math.sqrt(R * R - dv * dv)));
  }
  readonly property real coverStart: root._filletIn(root.startMargin, root._hidden)
  // (nothing once it's all behind the edge)
  readonly property real coverLength: root._hidden >= root.depth ? 0 : root.alongLength - root.coverStart - root._filletIn(root.endMargin, root._hidden)

  readonly property bool vertical: edge === Bar.Left || edge === Bar.Right
  readonly property bool attachLeft: edge === Bar.Left
  readonly property bool attachRight: edge === Bar.Right
  readonly property bool attachTop: edge === Bar.Top
  readonly property bool attachBottom: edge === Bar.Bottom

  // ---- Geometry, in edge-local coordinates ----
  // u runs along the attach edge, v away from it (v = 0 is the attach
  // edge). Everything below is laid out as if attached to the Top edge,
  // then mapped onto the real edge (SurfaceOutline.toItem).
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
  // The shape's metrics and paths (SurfaceOutline), so its footprint and
  // its copies agree with what's drawn. Its margins and natural start come
  // from what shapes its walls alone (`_baseSpec`): hosts place things by
  // them (a submenu, by the box's start) that decide how its joins look
  // (straightJoins) or whether a flush wall runs through, which mustn't
  // loop back into them.
  readonly property var _baseSpec: ({
      "edge": root.edge,
      "boxAlong": root.boxAlong,
      "boxDepth": root.boxDepth,
      "strokeWidth": root.strokeWidth,
      "filletRadius": root.filletRadius,
      "startCornerRadius": root.startCornerRadius,
      "endCornerRadius": root.endCornerRadius,
      "connectorGap": root.connectorGap,
      "joinStart": root.joinStart,
      "joinEnd": root.joinEnd,
      "flushStart": root.flushStart,
      "flushEnd": root.flushEnd,
      "detached": root.detached,
      "detachedOffset": root.detachedOffset,
      "backfill": root.backfill,
      "straight": root.straight
    })
  readonly property var _spec: Object.assign({}, root._baseSpec, {
    "flushStartThrough": root.flushStartThrough,
    "flushEndThrough": root.flushEndThrough,
    "straightJoins": root.straightJoins
  })
  readonly property var _natural: SurfaceOutline.metrics(root._baseSpec)
  readonly property var _m: SurfaceOutline.withBoxStart(root._spec, SurfaceOutline.metrics(root._spec), root.boxStart)
  // A radius under half the stroke (0 included) is too tight for a
  // fillet: its stroke's inner edge would need a negative radius, and its
  // margin (below) would go negative, pushing the walls out of the surface.
  // The walls run straight into what they attach to instead.
  readonly property bool _sharp: _natural.sharp
  // Whether each side wall ends in a fillet: not where the end is joined
  // or flush, nor where it runs straight off a bare screen edge
  readonly property bool _filletStart: _natural.filletStart
  readonly property bool _filletEnd: _natural.filletEnd
  readonly property bool _straightJoins: _m.straightJoins
  readonly property bool _joinFillet: _m.joinFillet
  // Room each end for a fillet square, minus the stroke overlap
  readonly property real startMargin: _natural.startMargin
  readonly property real endMargin: _natural.endMargin
  readonly property real alongLength: _natural.alongLength
  // Where the box starts away from the attach edge. Detached, a connector
  // gap's half past its lead. Attached, on the attach edge: the fillets
  // curve outside the side walls, so the band they span is the box's own
  // rather than empty padding above the content. Pushed back only as far
  // as a shallow box needs for a side wall to clear its fillet and far
  // corner.
  readonly property real naturalBoxStart: _natural.naturalBoxStart
  // Overridable: a bar's pills keep a half connector gap (sized by it)
  property real boxStart: naturalBoxStart
  // The box and the half connector gap past it (and a joined end's fillet
  // along the perpendicular stroke)
  readonly property real depth: _m.depth

  // Along the edge: box + fillet squares. Away from the edge: box +
  // connector gap.
  implicitWidth: vertical ? depth : alongLength
  implicitHeight: vertical ? alongLength : depth

  // Box sides and far edge (stroke centre line)
  readonly property real sideU: _natural.sideU
  readonly property real farSideU: _natural.farSideU
  readonly property real farV: _m.farV

  // The content box in this item's coordinates, at rest (not slid). On
  // every side but the attach edge it coincides with the outer edge of
  // the stroke, so things attaching to this surface (tray submenus) can
  // line their own stroke up with it.
  readonly property rect boxRect: root._rectFrom(startMargin, boxStart, boxAlong, boxDepth)

  // What it covers, in this item's coordinates at rest
  // (SurfaceOutline.footprint): the box, its fillets and backfill
  readonly property var footprint: SurfaceOutline.footprint(root._spec, root._m, root.width, root.height)

  // An edge-local rectangle (u, v, along, deep) in item coordinates
  function _rectFrom(u, v, along, deep) {
    const r = SurfaceOutline.rectFrom(edge, width, height, _back, u, v, along, deep);
    return Qt.rect(r.x, r.y, r.width, r.height);
  }

  // Fill: the outline, closed back along the attach edge.
  // Joined ends also cover the perpendicular stroke up to the fillet.
  readonly property string fillPath: SurfaceOutline.fillPath(root._spec, root._m, root.width, root.height)

  // Stroke: the outline alone, open along the attach edge and on joined
  // ends, whose ends sit exactly on the strokes they continue
  readonly property string strokePath: SurfaceOutline.strokePath(root._spec, root._m, root.width, root.height)

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
    // through a translucent fill), from a copy of it filled (its own fill
    // may be the blur window's): the content doesn't need its own
    OutsideShadow {
      target: shadowShape
      hideTarget: true
      active: root._ownShadow
      edge: root.edge
      falls: root.detached
    }

    Item {
      id: shadowShape
      anchors.fill: parent
      visible: root._ownShadow

      Shape {
        anchors.fill: parent
        visible: !root.detached
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
          fillColor: "black"
          strokeColor: "transparent"
          strokeWidth: 0

          PathSvg {
            path: root.fillPath
          }
        }

        ShapePath {
          fillColor: "transparent"
          strokeColor: "black"
          strokeWidth: root.strokeWidth
          capStyle: ShapePath.FlatCap
          joinStyle: ShapePath.MiterJoin

          PathSvg {
            path: root.strokePath
          }
        }
      }

      Rectangle {
        visible: root.detached
        x: detachedBox.x
        y: detachedBox.y
        width: detachedBox.width
        height: detachedBox.height
        topLeftRadius: detachedBox.topLeftRadius
        topRightRadius: detachedBox.topRightRadius
        bottomLeftRadius: detachedBox.bottomLeftRadius
        bottomRightRadius: detachedBox.bottomRightRadius
        color: "black"
      }
    }

    // The outline (or detached box)
    Item {
      id: outlineLayer
      anchors.fill: parent

      HoledItem {
        anchors.fill: parent
        visible: !root.detached
        holes: root.strokeHoles

        Shape {
          id: outline
          anchors.fill: parent
          preferredRendererType: Shape.CurveRenderer

          ShapePath {
            fillColor: root._fill
            strokeColor: "transparent"
            strokeWidth: 0

            PathSvg {
              path: root.fillPath
            }
          }

          ShapePath {
            fillColor: "transparent"
            strokeColor: root._stroke
            strokeWidth: root.strokeWidth
            capStyle: ShapePath.FlatCap
            joinStyle: ShapePath.MiterJoin

            PathSvg {
              path: root.strokePath
            }
          }
        }
      }

      // Detached: a box of its own, not joined to anything. Its far
      // corners square as the outline's do (start/endCornerRadius, the
      // stroke's centre line: the outer edge is half a stroke out).
      HoledItem {
        anchors.fill: parent
        visible: root.detached
        holes: root.strokeHoles

        Rectangle {
          id: detachedBox
          readonly property real startRadius: root.startCornerRadius > 0 ? root.startCornerRadius + root.half : 0
          readonly property real endRadius: root.endCornerRadius > 0 ? root.endCornerRadius + root.half : 0
          // Far corners from start/endRadius, near ones from start/endNearRadius
          topLeftRadius: root.attachBottom || root.attachRight ? detachedBox.startRadius : root.startNearRadius
          topRightRadius: root.attachLeft ? detachedBox.startRadius : root.attachBottom ? detachedBox.endRadius : root.attachTop ? root.endNearRadius : root.startNearRadius
          bottomLeftRadius: root.attachTop ? detachedBox.startRadius : root.attachRight ? detachedBox.endRadius : root.attachBottom ? root.startNearRadius : root.endNearRadius
          bottomRightRadius: root.attachTop || root.attachLeft ? detachedBox.endRadius : root.endNearRadius
          x: root.boxRect.x
          y: root.boxRect.y
          width: root.boxRect.width
          height: root.boxRect.height
          color: root._fill
          border.color: root._stroke
          border.width: root.strokeWidth
        }
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
      color: root._fill
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
