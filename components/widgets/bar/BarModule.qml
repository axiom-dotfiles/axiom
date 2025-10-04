// /components/reusable/BarModule.qml
pragma ComponentBehavior: Bound
import QtQuick
import qs.services
import qs.config

Item {
  id: component
  
  // -- Public API --
  property color backgroundColor: Theme.background
  property alias content: contentLoader.sourceComponent
  property alias contentItem: contentLoader.item
  
  // -- Layout Configuration --
  property int orientation: Config.orientation
  
  // -- Computed Properties --
  readonly property bool isVertical: orientation === Qt.Vertical
  
  // -- Sizing --
  height: isVertical ? implicitHeight : Widget.height
  width: isVertical ? Widget.height : implicitWidth
  implicitWidth: isVertical ? Widget.height : (contentLoader.item ? contentLoader.item.implicitWidth + Widget.padding * 2 : 60)
  implicitHeight: isVertical ? (contentLoader.item ? contentLoader.item.implicitHeight + Widget.padding * 2 : Widget.height) : Widget.height
  
  // -- Implementation --
  Loader {
    id: contentLoader
    anchors.centerIn: parent
  }
}
