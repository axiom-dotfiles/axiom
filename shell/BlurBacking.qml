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
// round those that cast one. It's the only one of them Hyprland blurs
// (HyprLua.blurSurfaces), in one pass, so where surfaces join their blur
// matches exactly.
Scope {
  id: root

  Variants {
    model: HyprlandManager.layerRulesReady && BlurManager.backing ? Quickshell.screens : []

    delegate: PanelWindow {
      id: backing
      required property ShellScreen modelData
      screen: modelData

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

      // The shadow round the shapes that cast one, as one, kept off every
      // shape
      OutsideShadow {
        target: shadowed
        cutBy: fills
        falls: false
      }

      // Every shape drawn opaque, then the surface opacity applied to them
      // all at once, so where they overlap they don't stack
      Item {
        id: fills
        anchors.fill: parent
        layer.enabled: true
        opacity: Appearance.surfaceAlpha

        ShapeGroup {
          id: shadowed
          shadowed: true
          screenName: backing.screen?.name ?? ""
        }

        ShapeGroup {
          shadowed: false
          screenName: backing.screen?.name ?? ""
        }
      }
    }
  }

  component ShapeGroup: Item {
    id: group
    required property bool shadowed
    required property string screenName
    anchors.fill: parent

    Repeater {
      // Changes only as a shape registers or goes
      model: BlurManager.shapes.filter(shape => shape.screen === group.screenName && shape.shadowed === group.shadowed)

      delegate: Loader {
        id: slot
        required property var modelData
        x: modelData.x
        y: modelData.y
        visible: modelData.shown
        sourceComponent: modelData.kind === "rect" ? rectMirror : modelData.kind === "frame" ? frameMirror : attachedMirror

        Component {
          id: attachedMirror

          AttachedSurface {
            readonly property var src: slot.modelData.source
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
            readonly property var src: slot.modelData.source
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
