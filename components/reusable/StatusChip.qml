pragma ComponentBehavior: Bound
import QtQuick
import qs.config

// A small filled pill with a bold word: a status (On, Running, Not
// installed) in its colour, on the settings page's status cards
Rectangle {
  id: root

  property string text: ""

  implicitWidth: label.implicitWidth + Widget.padding * 2
  implicitHeight: label.implicitHeight + 4
  radius: height / 2
  color: Theme.foregroundAlt

  StyledText {
    id: label
    anchors.centerIn: parent
    text: root.text
    textColor: Theme.background
    textSize: Appearance.fontSize - 2
    font.bold: true
  }
}
