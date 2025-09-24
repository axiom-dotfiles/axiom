pragma ComponentBehaviour: Bound

import QtQuick

import qs.services
import qs.config

Item {
  id: root

  property int orientation: Qt.Horizontal
  property color backgroundColor: Colors.surface
  property alias content: contentLoader.sourceComponent
  property alias contentItem: contentLoader.item
  property int padding: Settings.widgetPadding

  implicitWidth: contentLoader.item ? contentLoader.item.implicitWidth + padding * 2 : 0
  implicitHeight: contentLoader.item ? contentLoader.item.implicitHeight + padding * 2 : 0

  Rectangle {
    anchors.fill: parent
    color: root.backgroundColor
    radius: Settings.borderRadius
  }

  Loader {
    id: contentLoader
    anchors.centerIn: parent
  }
}
