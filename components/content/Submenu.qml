pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts

import qs.config
import qs.services
import qs.components.reusable
import qs.components.content.base
import qs.components.hosts.popout

// A row that opens another edge menu (`menu`) beside the one it's in, in
// that menu's submenu (EdgePopout.submenu, content/parts/MenuSubmenu): on
// hover, or on a click with openOnHover off. In a submenu it replaces
// that submenu in place (one level deep). Only a floating menu has a
// submenu: elsewhere (an integrated menu) the row is dimmed and inert.
// properties: { menu, label, icon, openOnHover }
Card {
  id: root

  readonly property string menuId: root.properties.menu
  readonly property var menu: root.menuId !== "" ? EdgeMenusConfig.menuById(root.menuId) : null
  // A menu that's gone, disabled, or this one (it'd open itself) opens
  // nothing
  readonly property bool opens: root.menu !== null && root.menu.enabled && root.menuId !== (root.host?.id ?? "") && anchor.popouts !== null
  readonly property string label: root.properties.label || (root.menu ? EdgeMenuManager.menuLabel(root.menu, 0) : I18n.tr("No menu"))
  readonly property bool isOpen: anchor.popoutOpen
  // Which way it opens, for the arrow
  readonly property bool toLeft: anchor.popouts?.openToLeft ?? false

  // The layouts editor showing the menu it opens (EdgeMenuManager's
  // previewing a submenu): held open from here, as if hovered
  // (the first such row in the menu, if there are more)
  readonly property bool previewed: root.menuId !== "" && EdgeMenuManager.previewing === root.menuId && EdgeMenuManager.previewParent !== "" && EdgeMenuManager.previewParent === (root.host?.id ?? "") && !root.host?.submenu && root._firstOpener
  readonly property bool _firstOpener: {
    const first = (EdgeMenusConfig.menuById(root.host?.id ?? "")?.modules ?? []).find(module => module?.type === "Submenu" && module.properties?.menu === root.menuId);
    return first?.place?.x === root.slotRect[0] && first?.place?.y === root.slotRect[1];
  }
  onPreviewedChanged: {
    if (root.previewed)
      anchor.open();
  }
  Component.onCompleted: {
    if (root.previewed)
      Qt.callLater(anchor.open);
  }

  fullMinWidth: Widget.height * 3
  color: root.bare ? "transparent" : Appearance.fill(Theme.background)
  opacity: root.opens || root.menuId === "" ? 1 : 0.5

  Rectangle {
    anchors.fill: parent
    anchors.margins: root.bare ? 0 : Appearance.borderWidth
    radius: Widget.radius
    color: root.isOpen ? Qt.alpha(Theme.accent, 0.2) : Qt.alpha(Theme.backgroundHighlight, area.containsMouse ? 0.5 : 0)

    ColorGlide on color {}
  }

  // What the anchor reads as hovered: the row, or the editor holding it
  QtObject {
    id: hit
    readonly property bool hovered: area.containsMouse || root.previewed
  }

  PopoutAnchor {
    id: anchor
    hitArea: hit
    popoutName: "parts/MenuSubmenu"
    active: root.opens
    openOnHover: root.properties.openOnHover
    extraData: ({
        "menuId": root.menuId,
        "parentId": root.host?.id ?? ""
      })
  }

  MouseArea {
    id: area
    anchors.fill: parent
    hoverEnabled: true
    cursorShape: root.opens ? Qt.PointingHandCursor : Qt.ArrowCursor
    onClicked: {
      if (!root.opens)
        return;
      if (root.isOpen)
        anchor.popouts.closePopout();
      else
        anchor.open();
    }
  }

  RowLayout {
    anchors.fill: parent
    anchors.leftMargin: root.pad
    anchors.rightMargin: root.pad
    spacing: Widget.spacing
    layoutDirection: root.toLeft ? Qt.RightToLeft : Qt.LeftToRight

    StyledIcon {
      visible: root.properties.icon !== ""
      text: root.properties.icon
      textColor: root.isOpen ? Theme.accent : Theme.foreground
    }

    StyledText {
      Layout.fillWidth: true
      visible: !root.compact
      text: root.label
      elide: Text.ElideRight
      horizontalAlignment: root.toLeft ? Text.AlignRight : Text.AlignLeft
    }

    StyledIcon {
      Layout.alignment: Qt.AlignVCenter
      text: root.toLeft ? "chevron_left" : "chevron_right"
      textColor: root.isOpen ? Theme.accent : Theme.foreground
      opacity: root.isOpen ? 1 : 0.6
    }
  }
}
