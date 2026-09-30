pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import qs.config

// A titled group of fields, as on the settings page (editor inspectors)
StyledContainer {
  id: root
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

    SectionHeading {
      title: root.title
      description: root.description
    }
  }
}
