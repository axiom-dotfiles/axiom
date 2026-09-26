pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import qs.config
import qs.services
import qs.components.reusable
import qs.components.content.base

// Keeps the edge menu it's in open when the pointer leaves (and from a
// click outside). Edge menus only: on an overlay page it does nothing.
Card {
  id: root

  readonly property bool inMenu: root.host?.kind === "edgeMenu" && !!root.host.id
  readonly property bool pinned: root.inMenu && EdgeMenuManager.pinnedMenus[root.host.id] === true

  color: root.pinned ? Theme.accent : Theme.background
  opacity: root.inMenu ? 1 : 0.5

  Behavior on color {
    ColorAnimation {
      duration: Appearance.animNormal
    }
  }

  ColumnLayout {
    anchors.centerIn: parent
    spacing: Widget.spacing / 2

    StyledIcon {
      Layout.alignment: Qt.AlignHCenter
      text: "push_pin"
      fill: root.pinned ? 1 : 0
      rotation: root.pinned ? 0 : 45
      textSize: Appearance.fontSize * (root.compact ? 2.2 : 3)
      textColor: root.pinned ? Theme.background : Theme.foreground

      Behavior on rotation {
        NumberAnimation {
          duration: Appearance.animNormal
        }
      }
    }

    StyledText {
      visible: !root.compact
      Layout.alignment: Qt.AlignHCenter
      text: !root.inMenu ? I18n.tr("Edge menus only") : root.pinned ? I18n.tr("Pinned") : I18n.tr("Pin open")
      textColor: root.pinned ? Theme.background : Theme.foreground
    }
  }

  MouseArea {
    anchors.fill: parent
    enabled: root.inMenu
    cursorShape: Qt.PointingHandCursor
    onClicked: EdgeMenuManager.togglePinned(root.host.id)
  }
}
