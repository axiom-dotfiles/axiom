pragma ComponentBehavior: Bound
import QtQuick
import qs.config
import qs.services
import qs.components.methods

// The layouts editor on an edge menu (EdgeMenuManager's selected menu):
// its modules against its screen, where the menu really sits on it, with
// the band along its edge and, on request, the other menus.
EditTarget {
  id: root

  readonly property var menu: EdgeMenuManager.selectedMenu()
  readonly property bool vertical: root.menu?.edge === "Left" || root.menu?.edge === "Right"
  readonly property var screen: root.menu ? EdgeMenusConfig.screenFor(root.menu) : null
  readonly property real length: root.menu ? EdgeMenusConfig.lengthOf(root.menu, root.vertical, EdgeMenuManager.cardUnitOf(root.menu)) : 0
  readonly property real edgeLength: root.screen ? (root.vertical ? root.screen.height : root.screen.width) : 0
  // Where the menu's modules sit on its screen (EdgeMenuManager.placementOf)
  readonly property var place: root.menu ? EdgeMenuManager.placementOf(root.menu) : null
  readonly property bool tooLong: root.menu?.length !== "edge" && root.edgeLength > 0 && root.length > root.edgeLength

  editor: EdgeMenuManager.layout
  modules: root.menu ? root.menu.modules : null
  icon: root.menu ? Utils.edgeArrow(root.menu.edge) : "side_navigation"
  title: root.menu ? EdgeMenuManager.menuLabel(root.menu, EdgeMenuManager.selectedMenuIndex) : I18n.tr("No edge menus")
  emptyText: I18n.tr("No edge menus yet: add one with New menu.")
  edge: root.menu ? root.menu.edge : ""
  screenBox: root.menu ? EdgeMenuManager.screenBoxOf(root.menu) : null
  screenSize: root.screen ? ({
      "width": root.screen.width,
      "height": root.screen.height
    }) : null
  reservedDepth: root.place ? GridPlacement.menuReservedDepth(root.place) : 0
  reservedLabel: root.place?.frame.reserves ? I18n.tr("Reserved while open") : I18n.tr("Bars and border")
  // The other enabled menus on its screen, in screen px
  ghosts: root.menu && EdgeMenuManager.showingOthers ? EdgeMenuManager.othersOn(EdgeMenuManager.selectedMenuIndex) : []
  fitText: {
    if (!root.menu)
      return "";
    if (root.menu.length === "edge")
      return I18n.tr("Takes its whole edge");
    if (root.tooLong)
      return I18n.tr("Longer than its edge: it scrolls");
    return I18n.tr("{0} px along its edge", Math.round(root.length));
  }
  fitWarning: root.tooLong
  editable: root.menu !== null
  notEditableHint: I18n.tr("Add a menu to put modules in it")
}
