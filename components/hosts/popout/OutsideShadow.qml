pragma ComponentBehavior: Bound
import QtQuick

// The shadow or glow (SurfaceShadow) a sibling `target` casts, kept only
// outside its shape, so none shows through a translucent fill. Declared
// before the target, so it's drawn under it. It captures the target with
// room for the shadow on every side, and the effect draws exactly that
// area: an effect padding its source itself (autoPaddingEnabled) stretches
// a texture it's handed, or redraws a layer it's handed, outline and all.
// A surface whose fill the blur window draws (BlurManager) has none of its
// own to cast from: its target is then a copy of its shape, filled, kept
// off screen (`hideTarget`).
Item {
  id: root

  required property Item target
  property bool active: true
  property alias edge: shadow.edge
  property alias falls: shadow.falls
  property alias look: shadow.look
  // Rects (in the target's coordinates) it isn't cast on either: where
  // surfaces joined to the target sit over it, whose translucent fill the
  // shadow would show (and blur) through
  property var holes: []
  // The target is drawn for the shadow alone: captured (and kept off
  // screen) whether or not the shadow shows
  property bool hideTarget: false
  readonly property real reach: Math.ceil(shadow.look.shadowSize * 1.25)

  x: target.x - reach
  y: target.y - reach
  width: target.width + reach * 2
  height: target.height + reach * 2
  visible: active && (target.visible || hideTarget) && shadow.shadowEnabled

  ShaderEffectSource {
    id: capture
    anchors.fill: parent
    visible: false
    sourceItem: root.visible || root.hideTarget ? root.target : null
    hideSource: root.hideTarget
    sourceRect: Qt.rect(-root.reach, -root.reach, root.width, root.height)
  }

  // The target and the holes, as the cut
  Item {
    id: cutMask
    anchors.fill: parent
    visible: false
    layer.enabled: root.holes.length > 0

    ShaderEffectSource {
      anchors.fill: parent
      sourceItem: root.holes.length > 0 ? capture.sourceItem : null
      sourceRect: capture.sourceRect
    }

    Repeater {
      model: root.holes.length

      Rectangle {
        required property int index
        readonly property rect hole: root.holes[index] ?? Qt.rect(0, 0, 0, 0)
        x: root.reach + hole.x
        y: root.reach + hole.y
        width: hole.width
        height: hole.height
        color: "black"
      }
    }
  }

  SurfaceShadow {
    id: shadow
    anchors.fill: parent
    source: capture
    cutSource: root.holes.length > 0 ? cutMask : capture
    autoPaddingEnabled: false
    cut: true
  }
}
