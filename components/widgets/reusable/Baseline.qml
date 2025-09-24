pragma ComponentBehaviour: Bound

import QtQuick

import qs.services
import qs.config

Item {
  id: root

  property int orientation: Qt.Horizontal
  property color backgroundColor: Theme.background
  property alias content: contentLoader.sourceComponent
  property alias contentItem: contentLoader.item
  property int padding: Widget.padding

  implicitWidth: contentLoader.item ? contentLoader.item.implicitWidth + padding * 2 : 0
  implicitHeight: contentLoader.item ? contentLoader.item.implicitHeight + padding * 2 : 0

  Rectangle {
    anchors.fill: parent
    color: root.backgroundColor
    radius: Appearance.borderRadius
  }

  Loader {
    id: contentLoader
    anchors.centerIn: parent
  }
}
