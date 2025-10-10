// /components/reusable/BarModule.qml
pragma ComponentBehavior: Bound
import QtQuick
import qs.services
import qs.config

Item {
  id: component
  
  required property var barConfig
  property var popouts
  property var panel
  property var screen

  required property var properties
  required property string componentPath

  property color backgroundColor: Theme.background
  property alias content: contentLoader.sourceComponent
  property alias contentItem: contentLoader.item
  property bool isVertical: barConfig.vertical
  
  // uhh TODO: not this
  implicitWidth: contentLoader.item ? (isVertical ? Widget.height : contentLoader.item.implicitWidth) : 60
  implicitHeight: contentLoader.item ? (isVertical ? contentLoader.item.implicitHeight: Widget.height) : Widget.height

  Loader {
    id: contentLoader
    source: component.componentPath
    anchors.centerIn: parent
    onLoaded: {
      console.log("Passing properties to widget (from BarModule):", JSON.stringify(component.properties));
      if (item) {
        item.barConfig = component.barConfig
        item.popouts = component.popouts
        item.panel = component.panel
        item.screen = component.screen
        item.properties = component.properties
      }
    }
  }
}
