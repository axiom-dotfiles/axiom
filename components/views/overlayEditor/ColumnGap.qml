pragma ComponentBehavior: Bound
import QtQuick
import qs.config
import qs.services
import qs.components.reusable

// The space before column `index` on the canvas (index = the column count
// for the end). While a cell, module or column is carried it's a drop
// target that makes a new column there (or moves the column there). The
// end one is also a button that adds an empty column; `wide` is the empty
// page's drop zone.
Item {
  id: root

  required property var dragLayer
  required property int index
  property bool isEnd: false
  property bool wide: false
  // Space kept clear before the box (the end one, after the last column)
  property real leadingSpace: 2

  readonly property string targetKind: "gap"
  readonly property bool hovered: root.dragLayer.hoverTarget === root
  readonly property bool active: root.dragLayer.carryingStructure

  Component.onCompleted: root.dragLayer.registerTarget(root)
  Component.onDestruction: root.dragLayer.unregisterTarget(root)

  Rectangle {
    anchors.fill: parent
    anchors.leftMargin: root.wide ? 0 : root.leadingSpace
    anchors.rightMargin: root.wide ? 0 : 2
    radius: Appearance.borderRadius
    visible: root.active || root.isEnd || root.wide
    color: root.hovered ? Qt.alpha(Theme.accent, 0.2) : (root.active ? Qt.alpha(Theme.accent, 0.06) : (addArea.containsMouse ? Theme.backgroundHighlight : "transparent"))
    border.color: root.hovered ? Theme.accent : (root.active ? Qt.alpha(Theme.accent, 0.4) : Theme.border)
    border.width: 1
    opacity: root.active || root.wide || addArea.containsMouse ? 1 : 0.6

    Behavior on color {
      ColorAnimation {
        duration: Appearance.animFast
      }
    }

    Column {
      anchors.centerIn: parent
      width: parent.width - 4
      spacing: Widget.spacing
      visible: root.isEnd || root.wide || root.hovered

      StyledIcon {
        width: parent.width
        horizontalAlignment: Text.AlignHCenter
        text: root.wide ? "add_column_right" : "add"
        textColor: root.hovered ? Theme.accent : Theme.foreground
        textSize: root.wide ? Appearance.fontSize + 12 : Appearance.fontSize + 4
      }

      StyledText {
        width: parent.width
        visible: root.wide
        horizontalAlignment: Text.AlignHCenter
        wrapMode: Text.WordWrap
        text: I18n.tr("An empty page: drag a module or a cell here from the library, or click to add a column.")
        opacity: 0.7
      }
    }
  }

  MouseArea {
    id: addArea
    anchors.fill: parent
    enabled: root.isEnd || root.wide
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    onClicked: root.dragLayer.editor.addColumn()
  }
}
