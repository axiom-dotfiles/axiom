pragma ComponentBehavior: Bound
import QtQuick

import qs.services
import qs.config

Item {
  id: root

  property int orientation: Config.orientation
  property bool isVertical: orientation === Qt.Vertical
  property color backgroundColor: Theme.background
  property alias content: contentLoader.sourceComponent
  property alias contentItem: contentLoader.item
  property int padding: Widget.padding

  height: isVertical ? implicitHeight : Widget.height
  width: isVertical ? Widget.height : implicitWidth

  implicitWidth: isVertical ? Widget.height : (contentLoader.item ? contentLoader.item.implicitWidth + padding * 2 : 60)

  implicitHeight: isVertical ? (contentLoader.item ? contentLoader.item.implicitHeight + padding * 2 : Widget.height) : Widget.height

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
