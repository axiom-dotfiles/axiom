pragma ComponentBehavior: Bound
import QtQuick

import qs.config
import qs.services
import qs.components.methods
import qs.components.reusable
import qs.components.hosts.overlay

// An edge menu's modules on a grid of half cards, as on a Custom overlay
// page, with cards of the menu's own cardSize. With `length: "edge"` the
// grid stretches along the edge to `maxLength`; otherwise it's capped
// there and scrolls past that.
Item {
  id: root

  required property var menu
  required property bool vertical
  // Room along the edge
  property real maxLength: 0

  // Modules re-read only when they actually change, so an unrelated config
  // save doesn't rebuild every module
  readonly property string _modulesKey: JSON.stringify(root.menu.modules)
  property var modules: []
  on_ModulesKeyChanged: root.modules = JSON.parse(root._modulesKey)
  Component.onCompleted: root.modules = JSON.parse(root._modulesKey)

  // `bare`: the menu hides its modules' card boxes (moduleBorders off)
  readonly property var host: ({
      "kind": "edgeMenu",
      "id": root.menu.id,
      "bare": !root.menu.moduleBorders
    })

  OverlayGrid {
    id: grid
    fixedUnit: root.menu.cardSize
  }

  // Whether the menu takes its whole edge
  readonly property bool fillsEdge: root.menu.length === "edge"
  readonly property var _natural: grid.sizes(GridPlacement.bounds(root.modules), null)
  // Along the edge before stretching or the cap
  readonly property real naturalLength: root.vertical ? root._natural.height : root._natural.width
  readonly property var _stretch: root.fillsEdge && root.maxLength > 0 ? (root.vertical ? {
      "height": root.maxLength
    } : {
      "width": root.maxLength
    }) : null

  readonly property real contentLength: root.vertical ? moduleGrid.implicitHeight : moduleGrid.implicitWidth
  readonly property real length: root.maxLength > 0 ? Math.min(root.contentLength, root.maxLength) : root.contentLength

  // Escape closes the menu once it has the keyboard (both hosts take it
  // on demand, when clicked)
  focus: true
  Keys.onEscapePressed: EdgeMenuManager.close(root.menu.id)

  implicitWidth: root.vertical ? moduleGrid.implicitWidth : root.length
  implicitHeight: root.vertical ? root.length : moduleGrid.implicitHeight

  Flickable {
    anchors.fill: parent
    contentWidth: moduleGrid.implicitWidth
    contentHeight: moduleGrid.implicitHeight
    clip: true
    boundsBehavior: Flickable.StopAtBounds
    interactive: root.contentLength > root.length

    ModuleGrid {
      id: moduleGrid
      modules: root.modules
      grid: grid
      stretch: root._stretch
      host: root.host
    }
  }

  // The menu's pin (pinButton): in the corner away from its edge, at the
  // end, over the modules' corner
  readonly property bool pinned: EdgeMenuManager.isPinned(root.menu.id)
  StyledIconButton {
    visible: root.menu.pinButton
    z: 2
    width: Widget.height
    height: Widget.height
    padding: 0
    anchors.top: root.menu.edge === "Top" ? undefined : parent.top
    anchors.bottom: root.menu.edge === "Top" ? parent.bottom : undefined
    anchors.right: root.menu.edge === "Right" ? undefined : parent.right
    anchors.left: root.menu.edge === "Right" ? parent.left : undefined
    anchors.margins: Widget.spacing / 2
    iconText: "push_pin"
    iconColor: root.pinned ? Theme.background : Theme.foreground
    backgroundColor: root.pinned ? Theme.accent : Qt.alpha(Theme.background, 0.85)
    hoverColor: root.pinned ? Theme.accent : Theme.backgroundHighlight
    borderColor: Theme.border
    tooltipText: root.pinned ? I18n.tr("Unpin: close as usual") : I18n.tr("Pin: keep this menu open")
    onClicked: EdgeMenuManager.togglePinned(root.menu.id)
  }
}
