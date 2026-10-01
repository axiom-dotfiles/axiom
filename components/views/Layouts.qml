pragma ComponentBehavior: Bound
import QtQuick
import qs.config
import qs.services
import qs.components.methods
import qs.components.views.layouts

// The layouts editor: always the last page (pinned by OverlayPages; not
// part of config). The overlay pages and edge menus on the left; the
// selected one's modules on a canvas (drag to move, drag a corner to
// resize) above the selected module's options, or the library to add
// from. Edits go through OverlayManager's and EdgeMenuManager's drafts
// until saved; a menu's show live on screen.
// i18n: keys from the schema (view labels)
BaseView {
  id: root

  readonly property bool editingMenu: OverlayManager.editTarget === "menu"
  readonly property var view: OverlayManager.selectedView()
  readonly property bool isCustom: root.view?.type === "Custom"
  readonly property var menu: EdgeMenuManager.selectedMenu()

  // How the page fits each monitor's overlay, or the menu its edge
  readonly property var fits: root.isCustom ? OverlayManager.fitOf(root.view.modules) : []
  readonly property bool shrunk: root.fits.some(fit => fit.scale < 0.999)
  readonly property string pageFitText: {
    if (root.fits.length === 0)
      return "";
    const shrunk = root.fits.filter(fit => fit.scale < 0.999);
    if (shrunk.length === 0)
      return I18n.tr("Fits {0}", root.fits.map(fit => fit.screen).join(", "));
    return shrunk.map(fit => I18n.tr("Shrunk to {0}% on {1}", Math.round(fit.scale * 100), fit.screen)).join(" · ");
  }
  readonly property bool menuVertical: root.menu?.edge === "Left" || root.menu?.edge === "Right"
  readonly property var menuScreen: root.menu ? EdgeMenusConfig.screenFor(root.menu) : null
  readonly property real menuLength: root.menu ? EdgeMenusConfig.lengthOf(root.menu, root.menuVertical, EdgeMenuManager.cardUnitOf(root.menu)) : 0
  readonly property real edgeLength: root.menuScreen ? (root.menuVertical ? root.menuScreen.height : root.menuScreen.width) : 0
  // Where the menu's modules sit on its screen (EdgeMenuManager.placementOf)
  readonly property var menuPlace: root.menu ? EdgeMenuManager.placementOf(root.menu) : null
  // The menu's screen around it, in grid units from its origin
  // (GridPlacement.screenBox), else null
  readonly property var menuScreenBox: root.menuPlace ? GridPlacement.screenBox(root.menuScreen.width, root.menuScreen.height, EdgeMenuManager.cardUnitOf(root.menu), GridPlacement.bounds(root.menu.modules), root.menu.edge, root.menuPlace.along, root.menuPlace.across) : null
  // What's taken along its edge: the strip an integrated menu reserves,
  // else the bars' and border's room the menu sits past
  readonly property real reservedDepth: {
    const place = root.menuPlace;
    if (!place)
      return 0;
    return place.frame.reserves ? place.across + place.depth + place.frame.after : place.frame.before;
  }
  // The other enabled menus on its screen, in screen px (GridCanvas.ghosts)
  readonly property var ghosts: {
    if (!root.menu || !root.menuScreen || !EdgeMenuManager.showingOthers)
      return [];
    const screenName = root.menuScreen.name;
    return (EdgeMenuManager.localMenus ?? []).map((other, i) => i !== EdgeMenuManager.selectedMenuIndex && other.enabled && EdgeMenusConfig.screenFor(other)?.name === screenName ? EdgeMenuManager.screenRectsOf(other, i) : null).filter(ghost => ghost !== null);
  }
  readonly property bool menuTooLong: root.menu?.length !== "edge" && root.edgeLength > 0 && root.menuLength > root.edgeLength
  readonly property string menuFitText: {
    if (!root.menu)
      return "";
    if (root.menu.length === "edge")
      return I18n.tr("Takes its whole edge");
    if (root.menuTooLong)
      return I18n.tr("Longer than its edge: it scrolls");
    return I18n.tr("{0} px along its edge", Math.round(root.menuLength));
  }

  Component.onCompleted: {
    OverlayManager.ensureLoaded();
    EdgeMenuManager.ensureLoaded();
  }
  // The page unloads when the overlay closes (or it pages two away)
  Component.onDestruction: EdgeMenuManager.stopPreviewing()

  LayoutsEditorLayout {
    id: layout
    grid: root.grid
    editor: root.editingMenu ? EdgeMenuManager.layout : OverlayManager.layout
    editModules: root.editingMenu ? (root.menu ? root.menu.modules : null) : (root.isCustom ? root.view.modules : null)
    canvasIcon: root.editingMenu ? (root.menu ? Utils.edgeArrow(root.menu.edge) : "side_navigation") : (root.view ? OverlayConfig.pageIcon(root.view) : "dashboard")
    canvasTitle: root.editingMenu ? (root.menu ? EdgeMenuManager.menuLabel(root.menu, EdgeMenuManager.selectedMenuIndex) : I18n.tr("No edge menus")) : (root.view ? OverlayConfig.viewLabel(root.view, OverlayManager.selectedViewIndex) : I18n.tr("No pages"))
    emptyText: root.editingMenu ? I18n.tr("No edge menus yet: add one with New menu.") : I18n.tr(root.view ? "A tool page: it has no layout to edit. Drag it in the list to reorder it." : "No pages yet: add one with New page.")
    edge: root.editingMenu && root.menu ? root.menu.edge : ""
    screenBox: root.editingMenu ? root.menuScreenBox : null
    screenSize: root.editingMenu && root.menuScreen ? ({
        "width": root.menuScreen.width,
        "height": root.menuScreen.height
      }) : null
    reservedDepth: root.editingMenu ? root.reservedDepth : 0
    reservedLabel: root.menuPlace?.frame.reserves ? I18n.tr("Reserved while open") : I18n.tr("Bars and border")
    ghosts: root.editingMenu ? root.ghosts : []
    fitText: root.editingMenu ? root.menuFitText : root.pageFitText
    fitWarning: root.editingMenu ? root.menuTooLong : root.shrunk
    editable: root.editingMenu ? root.menu !== null : root.isCustom
    notEditableHint: root.editingMenu ? I18n.tr("Add a menu to put modules in it") : I18n.tr("Pick one of your pages to add modules to it")
    dirty: OverlayManager.isDirty || EdgeMenuManager.isDirty
    canSave: OverlayManager.problems.length === 0 && EdgeMenuManager.problems.length === 0
    onSave: {
      if (OverlayManager.isDirty)
        OverlayManager.saveChanges();
      if (EdgeMenuManager.isDirty)
        EdgeMenuManager.saveChanges();
    }
    onReset: {
      OverlayManager.resetChanges();
      EdgeMenuManager.resetChanges();
    }

    LayoutsPanel {
      width: layout.sideWidth
      height: layout.pageHeight
      dragLayer: layout
    }
  }
}
