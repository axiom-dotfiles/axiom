pragma ComponentBehavior: Bound

import Quickshell
import Quickshell.Wayland
import QtQuick

import qs.config
import qs.services

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
// While the overlay is open on a screen it covers that window, so a second
// one, over the overlay and under the surfaces on the Overlay layer (bar
// and edge popouts, submenus, the OSD), draws those surfaces' shapes
// (BlurShape.overlayLayer, BlurManager.aboveOverlay), blurring the overlay
// under them. Bars' fills can't move up with them: drawn over the Top
// layer, they'd cover the bars' content.
Scope {
  id: root

  Variants {
    model: BlurManager.backing ? General.outputs : []

    delegate: Scope {
      id: perScreen
      required property ShellScreen modelData
      readonly property string screenName: perScreen.modelData?.name ?? ""
      readonly property var onScreen: BlurManager.shapes.filter(shape => shape.screen === perScreen.screenName)
      // The overlay open here covers the blur window: the Overlay-layer
      // surfaces' shapes go to the one over it
      readonly property bool aboveOverlay: BlurManager.aboveOverlay(perScreen.screenName)
      readonly property var overlayShapes: perScreen.aboveOverlay ? perScreen.onScreen.filter(shape => shape.overlayLayer) : []
      readonly property var otherShapes: perScreen.aboveOverlay ? perScreen.onScreen.filter(shape => !shape.overlayLayer) : perScreen.onScreen

      // On Top, under the chrome; on Overlay (under every surface there,
      // by its order) while a fullscreen window hides the Top layer, for
      // the surfaces shown over it (BlurManager.overFullscreen)
      BlurBackingWindow {
        screen: perScreen.modelData
        shapes: perScreen.otherShapes
        cutBy: perScreen.overlayShapes
        WlrLayershell.layer: BlurManager.overFullscreen(perScreen.screenName) ? WlrLayer.Overlay : WlrLayer.Top
        WlrLayershell.namespace: "axiom-blur-backing"
      }

      // Over the overlay and under the surfaces on the Overlay layer (by
      // its order), while the overlay is open here: their blur is the
      // overlay's content, not what the overlay covers
      LazyLoader {
        active: perScreen.aboveOverlay

        BlurBackingWindow {
          screen: perScreen.modelData
          shapes: perScreen.overlayShapes
          cutBy: perScreen.otherShapes
          WlrLayershell.layer: WlrLayer.Overlay
          WlrLayershell.namespace: "axiom-blur-backing-overlay"
        }
      }
    }
  }
}
