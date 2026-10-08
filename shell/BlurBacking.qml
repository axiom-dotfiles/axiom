pragma ComponentBehavior: Bound

import Quickshell
import Quickshell.Wayland
import QtQuick
import QtQuick.Shapes

import qs.config
import qs.services
import qs.components.hosts.popout

// The blur behind the chrome (BlurManager): per screen, one click-through
// window under every chrome surface drawing each registered shape (the
// border's frame, bars, popouts, edge menus, docks) filled, with one shadow
// round those casting the same one (a bar may have its own). It's the only
// one of them Hyprland blurs (HyprLua.blurSurfaces), in one pass, so where
// surfaces join their blur matches exactly.
Scope {
  id: root

  Variants {
    model: HyprlandManager.layerRulesReady && BlurManager.backing ? Quickshell.screens : []

    delegate: PanelWindow {
      id: backing
      required property ShellScreen modelData
      screen: modelData

      readonly property string screenName: backing.screen?.name ?? ""
      readonly property var shapes: BlurManager.shapes.filter(shape => shape.screen === backing.screenName)
      // The shadows cast here, by BlurShape.shadowKey ("" first: none), as
      // a joined string, so the groups are remade only as one comes or goes
      readonly property string shadowKeys: [""].concat(backing.shapes.map(shape => shape.shadowKey).filter((key, i, keys) => key !== "" && keys.indexOf(key) === i)).join("\n")

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

      // Each shadow round the shapes casting it, as one, kept off every
      // shape
      Repeater {
        model: groups.count

        OutsideShadow {
          required property int index
          // Again as the groups are remade (their count may not change)
          readonly property var group: fills.revision >= 0 ? groups.itemAt(index) : null
          target: group ?? fills
          active: index > 0 && group !== null
          look: group?.look ?? BarStyle.values
          cutBy: fills
          falls: false
        }
      }

      // Every shape drawn opaque, then the surface opacity applied to them
      // all at once, so where they overlap they don't stack
      Item {
        id: fills
        anchors.fill: parent
        layer.enabled: true
        opacity: Appearance.surfaceAlpha
        property int revision: 0

        Repeater {
          id: groups
          model: backing.shadowKeys.split("\n")
          onItemAdded: fills.revision++
          onItemRemoved: fills.revision++

          ShapeGroup {
            required property string modelData
            shadowKey: modelData
            shapes: backing.shapes
          }
        }
      }
    }
  }

  component ShapeGroup: Item {
    id: group
    required property string shadowKey
    // This screen's shapes
    required property var shapes
    // The look its shapes cast (any of them: they cast the same)
    readonly property var look: group.shapes.find(shape => shape.shadowKey === group.shadowKey)?.look ?? null
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

    Repeater {
      // Changes only as a shape registers or goes
      model: group.shapes.filter(shape => shape.shadowKey === group.shadowKey)

      // Cut to the shape's clipRect (its window), if it has one
      delegate: Item {
        id: slot
        required property var modelData
        readonly property var area: modelData.clipRect
        x: area ? area.x : 0
        y: area ? area.y : 0
        width: area ? area.width : group.width
        height: area ? area.height : group.height
        clip: !!area
        visible: modelData.shown && !!modelData.source

        Loader {
          x: slot.modelData.x - slot.x
          y: slot.modelData.y - slot.y
          sourceComponent: slot.modelData.kind === "rect" ? rectMirror : slot.modelData.kind === "frame" ? frameMirror : attachedMirror
        }

        Component {
          id: attachedMirror

          AttachedSurface {
            readonly property var src: slot.modelData.source ?? blankSurface
            mirror: true
            width: src.width
            height: src.height
            edge: src.edge
            active: src.active
            animationDuration: src.animationDuration
            boxWidth: src.boxWidth
            boxHeight: src.boxHeight
            boxStart: src.boxStart
            connectorGap: src.connectorGap
            joinStart: src.joinStart
            joinEnd: src.joinEnd
            flushStart: src.flushStart
            flushEnd: src.flushEnd
            flushStartThrough: src.flushStartThrough
            flushEndThrough: src.flushEndThrough
            detached: src.detached
            detachedOffset: src.detachedOffset
            backfill: src.backfill
            joinBackfill: src.joinBackfill
            straight: src.straight
            straightJoins: src.straightJoins
            startCornerRadius: src.startCornerRadius
            endCornerRadius: src.endCornerRadius
            startNearRadius: src.startNearRadius
            endNearRadius: src.endNearRadius
            fillColor: src.fillColor
          }
        }

        Component {
          id: rectMirror

          Rectangle {
            readonly property var src: slot.modelData.source ?? blankRect
            width: src.width
            height: src.height
            topLeftRadius: src.topLeftRadius
            topRightRadius: src.topRightRadius
            bottomLeftRadius: src.bottomLeftRadius
            bottomRightRadius: src.bottomRightRadius
            color: slot.modelData.color
          }
        }

        // The screen border's frame (RoundedBorders): the screen, less its
        // integrated menus' strips, round the stroke's inner side
        Component {
          id: frameMirror

          Shape {
            id: frame
            readonly property var src: slot.modelData.source
            width: group.width
            height: group.height
            preferredRendererType: Shape.CurveRenderer

            ShapePath {
              fillColor: slot.modelData.color
              fillRule: ShapePath.OddEvenFill
              strokeColor: "transparent"
              strokeWidth: 0

              PathSvg {
                readonly property real w: frame.width
                readonly property real h: frame.height
                readonly property real ox0: frame.src.outerLeft
                readonly property real oy0: frame.src.outerTop
                readonly property real ox1: w - frame.src.outerRight
                readonly property real oy1: h - frame.src.outerBottom
                readonly property real x0: frame.src.innerLeft
                readonly property real y0: frame.src.innerTop
                readonly property real x1: w - frame.src.innerRight
                readonly property real y1: h - frame.src.innerBottom
                readonly property real r: Math.max(0, Math.min(frame.src.innerRadius, (x1 - x0) / 2, (y1 - y0) / 2))

                path: `M ${ox0} ${oy0} L ${ox1} ${oy0} L ${ox1} ${oy1} L ${ox0} ${oy1} Z M ${x0 + r} ${y0} L ${x1 - r} ${y0} A ${r} ${r} 0 0 1 ${x1} ${y0 + r} L ${x1} ${y1 - r} A ${r} ${r} 0 0 1 ${x1 - r} ${y1} L ${x0 + r} ${y1} A ${r} ${r} 0 0 1 ${x0} ${y1 - r} L ${x0} ${y0 + r} A ${r} ${r} 0 0 1 ${x0 + r} ${y0} Z`
              }
            }
          }
        }
      }
    }
  }
}
