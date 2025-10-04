// /components/reusable/BarModule.qml
pragma ComponentBehavior: Bound
import QtQuick
import qs.services
import qs.config

Item {
  id: component
  
  // -- Public API --
  required property var barConfig
  required property string componentPath
  property color backgroundColor: Theme.background
  property alias content: contentLoader.sourceComponent
  property alias contentItem: contentLoader.item
  property bool isVertical: barConfig.vertical
  
  // -- Sizing --
  height: barConfig.vertical ? implicitHeight : Widget.height
  width: barConfig.vertical ? Widget.height : implicitWidth
  implicitWidth: barConfig.vertical ? Widget.height : (contentLoader.item ? contentLoader.item.implicitWidth + Widget.padding * 2 : 60)
  implicitHeight: barConfig.vertical ? (contentLoader.item ? contentLoader.item.implicitHeight + Widget.padding * 2 : Widget.height) : Widget.height

  // -- Implementation --
  Loader {
    id: contentLoader
    source: componentPath
    property bool isVertical: barConfig.vertical
    anchors.centerIn: parent
  }
}
