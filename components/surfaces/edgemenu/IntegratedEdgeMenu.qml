pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Wayland

import qs.config
import qs.services
import qs.components.hosts.popout

// An integrated edge menu: a Top-layer strip along the whole edge whose
// exclusive zone is arranged before everything else's (the axiom-edge-menu
// layer rule, HyprlandManager._addLayerRules), so it sits outermost and the
// border, bars and windows move inwards while it's open. The zone is set
// once when it opens (windows retile in one step), then the strip slides
// in; closing slides it out before the zone goes.
//
// Open/close and hover-loss dismissal are PopoutWrapperBase's, as for the
// popouts.
PopoutWrapperBase {
  id: root

  required property var menu
  required property ShellScreen screen

  readonly property string menuId: root.menu?.id ?? ""
  readonly property bool pinned: EdgeMenuManager.pinnedMenus[root.menuId] === true
  readonly property bool wanted: EdgeMenuManager.openMenus[root.menuId] === true
  readonly property bool isOpen: root.occupied && !root.isClosing

  readonly property int edge: EdgeMenusConfig.edgeOf(root.menu)
  readonly property bool vertical: root.edge === Bar.Left || root.edge === Bar.Right
  readonly property real position: (root.menu?.position ?? 50) / 100

  // Space around the cards: to the screen edge and the strip's ends, and,
  // with the screen border off, to the strip's own inner stroke (with it
  // on, the border's strip inside this one leaves that gap)
  readonly property int pad: Appearance.screenMargin
  readonly property int innerPad: Appearance.screenBorder ? 0 : root.pad + Appearance.borderWidth
  readonly property real edgeLength: root.vertical ? root.screen.height : root.screen.width
  readonly property real bodyDepth: root.vertical ? (loader.item?.implicitWidth ?? 0) : (loader.item?.implicitHeight ?? 0)
  readonly property int depth: Math.ceil(root.bodyDepth + root.pad + root.innerPad)

  autoDismiss: (root.menu?.closeOnLeave ?? true) && !root.pinned
  onAutoDismissChanged: root.updateDismissTimer()
  keepAlive: panelHover.hovered || trigger.containsMouse

  function show(data) {
    if (root.isOpen) {
      root.updateDismissTimer();
      return;
    }
    root.safeOpenPopout(null, data ?? ({}));
  }

  function hide() {
    if (root.isOpen)
      root.requestDismiss();
  }

  // Follow EdgeMenuManager, and tell it when the menu closes by itself
  function _sync() {
    if (root.wanted && !root.isOpen)
      root.show({
        "anchorItem": EdgeMenuManager.anchors[root.menuId] ?? null
      });
    else if (!root.wanted && root.isOpen)
      root.hide();
  }
  onWantedChanged: _sync()
  onIsOpenChanged: {
    if (!root.isOpen && root.wanted && !root.hasPendingOpen)
      EdgeMenuManager.close(root.menuId);
    else if (root.isOpen && !root.wanted)
      EdgeMenuManager.open(root.menuId, null);
  }
  Component.onCompleted: {
    ShellManager.registerGrabPartner(panel, root.screen?.name ?? "");
    Qt.callLater(root._sync);
  }
  Component.onDestruction: {
    ShellManager.unregisterGrabPartner(panel);
    EdgeMenuManager.setZone(root.screen?.name ?? "", root._edgeName, 0);
  }

  // Report the space taken, for surfaces laid out against this edge
  readonly property string _edgeName: ["top", "bottom", "left", "right"][root.edge]
  readonly property int reserved: panel.visible ? root.depth : 0
  onReservedChanged: EdgeMenuManager.setZone(root.screen?.name ?? "", root._edgeName, root.reserved)

  EdgeTrigger {
    id: trigger
    screen: root.screen
    visible: root.menu?.openOnHover ?? false
    edge: root.edge
    position: root.position
    triggerWidth: PopoutConfig.edgeTriggerSize
    triggerLength: 200
    hoverDelay: PopoutConfig.openDelay
    onTriggered: root.show()
  }

  PanelWindow {
    id: panel
    screen: root.screen
    // Mapped only while open: the zone (and the windows moving) goes with it
    visible: root.occupied && loader.status === Loader.Ready
    color: "transparent"

    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.namespace: "axiom-edge-menu"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand
    exclusionMode: ExclusionMode.Normal
    exclusiveZone: root.depth

    anchors {
      top: root.edge === Bar.Top || root.vertical
      bottom: root.edge === Bar.Bottom || root.vertical
      left: root.edge === Bar.Left || !root.vertical
      right: root.edge === Bar.Right || !root.vertical
    }

    implicitWidth: root.vertical ? root.depth : 0
    implicitHeight: root.vertical ? 0 : root.depth

    SlideAnimation {
      anchors.fill: parent
      active: root.isOpen
      slideFromLeft: root.edge === Bar.Left
      slideFromRight: root.edge === Bar.Right
      slideFromTop: root.edge === Bar.Top
      slideFromBottom: root.edge === Bar.Bottom
      enableFade: false
      containerWidth: panel.width
      containerHeight: panel.height

      // One item, since the slide's content takes items only
      Item {
        anchors.fill: parent

        HoverHandler {
          id: panelHover
        }

        // The strip, in the border's colours: the screen frame grown by the menu
        Rectangle {
          anchors.fill: parent
          color: Theme.background
        }

        // With the screen border off, nothing inside draws the frame's stroke
        Rectangle {
          visible: !Appearance.screenBorder
          color: Theme.foreground
          width: root.vertical ? Appearance.borderWidth : parent.width
          height: root.vertical ? parent.height : Appearance.borderWidth
          x: root.edge === Bar.Left ? parent.width - width : 0
          y: root.edge === Bar.Top ? parent.height - height : 0
        }

        Loader {
          id: loader
          active: root.occupied

          readonly property real along: root.vertical ? height : width
          readonly property real alongPos: Math.max(root.pad, Math.min(root.edgeLength * root.position - along / 2, root.edgeLength - along - root.pad))
          readonly property real across: root.edge === Bar.Left || root.edge === Bar.Top ? root.pad : root.innerPad

          x: root.vertical ? across : alongPos
          y: root.vertical ? alongPos : across

          sourceComponent: EdgeMenuBody {
            menu: root.menu
            vertical: root.vertical
            maxLength: root.edgeLength - root.pad * 2
          }

          onLoaded: root.updateDismissTimer()
        }
      }
    }
  }
}
