pragma ComponentBehavior: Bound

import Quickshell
import Quickshell.Wayland
import QtQuick
import QtQuick.Shapes

import qs.config
import qs.services
import qs.components.hosts.popout
import qs.components.reusable

// The blur behind the chrome (BlurManager): per screen, one click-through
// window under every chrome surface drawing each registered shape (the
// border's frame, bars, popouts, edge menus, docks) filled. It's the only
// one of them Hyprland blurs (HyprLua.blurSurfaces), in one pass, so where
// surfaces join their blur matches exactly. Their shadows are cast here
// too, from the same copies: one per look (BlurShape.shadow), kept only
// outside every shape, so a shadow runs unbroken round joined surfaces as
// round one (surfaces each casting their own, cut where the others sit,
// never met at a join). They stay under Hyprland's blur threshold
// (Appearance.shadowAlphaMax), so they aren't blurred.
// The copies are keyed (KeyedModel): one coming or going adds or removes
// only its own, so the others aren't remade (and don't restart).
Scope {
  id: root

  // Which shadow a shape casts with: shapes of one look, falling the same
  // way, cast theirs together; "none" for no shadow
  function shadowKey(shape) {
    const look = shape?.shadow ?? null;
    if (!look || look.shadow === "none")
      return "none";
    const even = look.shadow === "glow" || !shape.shadowFalls;
    return [look.shadow, look.shadowColor, look.shadowSize, even ? "even" : shape.shadowEdge].join("|");
  }

  Variants {
    model: HyprlandManager.layerRulesReady && BlurManager.backing ? Quickshell.screens : []

    delegate: PanelWindow {
      id: backing
      required property ShellScreen modelData
      screen: modelData

      readonly property string screenName: backing.screen?.name ?? ""
      readonly property var shapes: BlurManager.shapes.filter(shape => shape.screen === backing.screenName)

      WlrLayershell.layer: WlrLayer.Top
      WlrLayershell.namespace: "axiom-blur-backing"
      WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
      exclusionMode: ExclusionMode.Ignore
      color: "transparent"
      mask: Region {}

      anchors {
        top: true
        bottom: true
        left: true
        right: true
      }

      // Shown as drawn, whatever Hyprland held on to (see FrameNudge)
      FrameNudge {
        id: nudge
      }

      // The shadows, under the fills
      Item {
        id: shadows
        anchors.fill: parent
      }

      // Every shape drawn opaque (by shadow, in `groups`), then the surface
      // opacity applied to them all at once, so where they overlap they
      // don't stack (a layer of its own only once there are several)
      Item {
        id: fills
        anchors.fill: parent
        layer.enabled: groups.count > 1
        opacity: Appearance.surfaceAlpha
      }

      // Every shape, as the shadows' cut: each is kept outside them all,
      // so none falls on a surface joined to the one casting it. Captured
      // (and kept off screen) only once there are several groups.
      Item {
        id: unionShapes
        anchors.fill: parent
      }
      ShaderEffectSource {
        id: union
        anchors.fill: parent
        visible: false
        sourceItem: groups.count > 1 ? unionShapes : null
        hideSource: true
      }

      KeyedModel {
        id: groupModel
        keys: backing.shapes.map(shape => root.shadowKey(shape)).filter((key, i, all) => all.indexOf(key) === i)
      }

      // The shapes casting one shadow: copied once, captured (a hidden
      // layer isn't drawn, a capture with hideSource is), drawn into
      // `fills` and `union` from the capture, and casting from it
      Repeater {
        id: groups
        model: groupModel.model

        delegate: Item {
          id: group
          required property string key
          readonly property var members: backing.shapes.filter(shape => root.shadowKey(shape) === group.key)
          readonly property var lead: group.members[0] ?? null
          anchors.fill: parent

          Item {
            id: shapes
            anchors.fill: parent

            Copies {
              shapes: group.members
              onChanged: nudge.burst()
            }
          }

          ShaderEffectSource {
            id: copied
            anchors.fill: parent
            visible: false
            sourceItem: shapes
            hideSource: true
          }

          ShaderEffect {
            property var source: copied
            parent: fills
            anchors.fill: parent
          }

          ShaderEffect {
            property var source: copied
            parent: unionShapes
            anchors.fill: parent
            visible: groups.count > 1
          }

          SurfaceShadow {
            parent: shadows
            anchors.fill: parent
            visible: group.key !== "none" && group.lead !== null
            source: copied
            cut: true
            cutSource: groups.count > 1 ? union : copied
            autoPaddingEnabled: false
            look: group.lead?.shadow ?? BarStyle.values
            edge: group.lead?.shadowEdge ?? -1
            falls: group.lead?.shadowFalls ?? true
          }
        }
      }
    }
  }

  // `model`: a ListModel of `key` rows (strings), kept to `keys` by
  // adding and removing rows rather than resetting it, so a Repeater over
  // it keeps the items whose keys stay
  component KeyedModel: QtObject {
    id: keyed
    required property var keys
    readonly property ListModel model: ListModel {}

    function sync() {
      const wanted = keyed.keys.map(key => String(key));
      for (let i = keyed.model.count - 1; i >= 0; i--) {
        if (!wanted.includes(keyed.model.get(i).key))
          keyed.model.remove(i);
      }
      const have = [];
      for (let i = 0; i < keyed.model.count; i++)
        have.push(keyed.model.get(i).key);
      for (const key of wanted) {
        if (!have.includes(key))
          keyed.model.append({
            "key": key
          });
      }
    }
    onKeysChanged: keyed.sync()
    Component.onCompleted: keyed.sync()
  }

  // A copy of each of `shapes`
  component Copies: Item {
    id: copies
    required property var shapes
    // A copy moved, resized, showed or hid
    signal changed
    anchors.fill: parent

    // What a copy reads while its source is going (destroyed before its
    // BlurShape leaves the list)
    AttachedSurface {
      id: blankSurface
      visible: false
      edge: Bar.Top
    }
    Rectangle {
      id: blankRect
      visible: false
    }

    KeyedModel {
      id: shapeModel
      keys: copies.shapes.map(shape => shape.uid)
    }

    Repeater {
      model: shapeModel.model

      // Cut to the shape's clipRect (its window), if it has one
      delegate: Item {
        id: slot
        required property string key
        // Fixed per key; null once it's gone, until its row goes
        readonly property var shape: BlurManager.shapeOf(Number(slot.key))
        readonly property var area: slot.shape?.clipRect ?? null
        x: area ? area.x : 0
        y: area ? area.y : 0
        width: area ? area.width : copies.width
        height: area ? area.height : copies.height
        clip: !!area
        // (read rather than `visible`, which is false inside a hidden layer)
        readonly property bool showing: (slot.shape?.shown ?? false) && !!slot.shape?.source
        visible: slot.showing

        // Where and how big its copy is, as drawn: on any change the
        // window is nudged to show its last frame
        readonly property string drawn: [mirror.x, mirror.y, mirror.width, mirror.height, slot.showing, (mirror.item as AttachedSurface)?.slid ?? 0].join(",")
        onDrawnChanged: copies.changed()

        Loader {
          id: mirror
          x: (slot.shape?.x ?? 0) - slot.x
          y: (slot.shape?.y ?? 0) - slot.y
          active: slot.shape !== null
          sourceComponent: slot.shape?.kind === "rect" ? rectMirror : slot.shape?.kind === "frame" ? frameMirror : attachedMirror
        }

        Component {
          id: attachedMirror

          AttachedSurfaceCopy {
            source: slot.shape?.source ?? blankSurface
          }
        }

        Component {
          id: rectMirror

          Rectangle {
            readonly property var src: slot.shape?.source ?? blankRect
            width: src.width
            height: src.height
            topLeftRadius: src.topLeftRadius
            topRightRadius: src.topRightRadius
            bottomLeftRadius: src.bottomLeftRadius
            bottomRightRadius: src.bottomRightRadius
            color: slot.shape?.color ?? "transparent"
          }
        }

        // The screen border's frame (RoundedBorders): the screen, less its
        // integrated menus' strips, round the stroke's inner side
        Component {
          id: frameMirror

          Shape {
            id: frame
            readonly property var src: slot.shape?.source ?? null
            width: copies.width
            height: copies.height
            preferredRendererType: Shape.CurveRenderer

            ShapePath {
              fillColor: slot.shape?.color ?? "transparent"
              fillRule: ShapePath.OddEvenFill
              strokeColor: "transparent"
              strokeWidth: 0

              PathSvg {
                readonly property real w: frame.width
                readonly property real h: frame.height
                readonly property real ox0: (frame.src?.outerLeft ?? 0)
                readonly property real oy0: (frame.src?.outerTop ?? 0)
                readonly property real ox1: w - (frame.src?.outerRight ?? 0)
                readonly property real oy1: h - (frame.src?.outerBottom ?? 0)
                readonly property real x0: (frame.src?.innerLeft ?? 0)
                readonly property real y0: (frame.src?.innerTop ?? 0)
                readonly property real x1: w - (frame.src?.innerRight ?? 0)
                readonly property real y1: h - (frame.src?.innerBottom ?? 0)
                readonly property real r: Math.max(0, Math.min((frame.src?.innerRadius ?? 0), (x1 - x0) / 2, (y1 - y0) / 2))

                path: `M ${ox0} ${oy0} L ${ox1} ${oy0} L ${ox1} ${oy1} L ${ox0} ${oy1} Z M ${x0 + r} ${y0} L ${x1 - r} ${y0} A ${r} ${r} 0 0 1 ${x1} ${y0 + r} L ${x1} ${y1 - r} A ${r} ${r} 0 0 1 ${x1 - r} ${y1} L ${x0 + r} ${y1} A ${r} ${r} 0 0 1 ${x0} ${y1 - r} L ${x0} ${y0 + r} A ${r} ${r} 0 0 1 ${x0 + r} ${y0} Z`
              }
            }
          }
        }
      }
    }
  }
}
