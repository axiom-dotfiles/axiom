pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import qs.config

// An outlined full-width button under a list that adds to it ("New bar",
// "Paste style to all bars")
StyledContainer {
  id: root

  property string text
  property string icon: "add"

  signal clicked

  Layout.fillWidth: true
  Layout.preferredHeight: Widget.height
  backgroundColor: area.containsMouse ? Theme.backgroundHighlight : "transparent"
  borderColor: Theme.border
  borderWidth: 1

  RowLayout {
    anchors.centerIn: parent
    spacing: Widget.spacing
    opacity: area.containsMouse ? 1 : 0.7

    StyledIcon {
      text: root.icon
    }

    StyledText {
      text: root.text
    }
  }

  MouseArea {
    id: area
    anchors.fill: parent
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    onClicked: root.clicked()
  }
}
