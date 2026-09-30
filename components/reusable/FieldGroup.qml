pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import qs.config

// A titled group of fields, as on the settings page (editor inspectors)
StyledContainer {
  id: group
  property string title
  property string description
  default property alias content: groupColumn.data

  Layout.fillWidth: true
  Layout.alignment: Qt.AlignTop
  implicitHeight: groupColumn.implicitHeight + Widget.padding * 2
  backgroundColor: Theme.backgroundAlt

  ColumnLayout {
    id: groupColumn
    anchors.top: parent.top
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.margins: Widget.padding
    spacing: Widget.spacing * 1.5

    StyledText {
      text: group.title
      textColor: Theme.accent
      textSize: Appearance.fontSize + 1
      font.bold: true
      Layout.fillWidth: true
    }

    StyledText {
      visible: group.description !== ""
      text: group.description
      opacity: 0.7
      textSize: Appearance.fontSize - 2
      wrapMode: Text.WordWrap
      Layout.fillWidth: true
      Layout.topMargin: -Widget.spacing
    }
  }
}
