pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import qs.config

// A SectionHeading with a chevron over a FoldingColumn: clicking the
// heading emits `toggled`, and the body folds shut while `collapsed`.
// FoldingCard's fold without the card, for sections inside one (the theme
// list's groups).
ColumnLayout {
  id: root

  property string title
  // Shown only while unfolded
  property string description
  property bool collapsed: false
  property alias bodySpacing: body.spacing
  default property alias content: body.content

  signal toggled

  Layout.fillWidth: true
  spacing: Widget.spacing

  Item {
    Layout.fillWidth: true
    implicitHeight: header.implicitHeight

    MouseArea {
      id: headerArea
      anchors.fill: parent
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      onClicked: root.toggled()
    }

    RowLayout {
      id: header
      anchors.left: parent.left
      anchors.right: parent.right
      spacing: Widget.spacing

      SectionHeading {
        title: root.title
        description: root.collapsed ? "" : root.description
      }

      StyledIcon {
        text: "expand_more"
        textColor: headerArea.containsMouse ? Theme.accent : Theme.foregroundAlt
        textSize: Appearance.fontSize + 4
        rotation: root.collapsed ? -90 : 0
        Layout.alignment: Qt.AlignTop

        Glide on rotation {}
      }
    }
  }

  FoldingColumn {
    id: body
    open: !root.collapsed
    Layout.fillWidth: true
    spacing: Widget.spacing
  }
}
