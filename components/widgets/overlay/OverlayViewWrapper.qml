pragma ComponentBehavior: Bound
import QtQuick

Item {
  id: viewWrapper
  required property var screen
  required property var viewModel
  
  implicitWidth: viewLoader.item ? viewLoader.item.implicitWidth : 0
  implicitHeight: viewLoader.item ? viewLoader.item.implicitHeight : 0
  
  Loader {
    id: viewLoader
    anchors.centerIn: parent
    source: viewWrapper.viewModel.component
    
    onLoaded: {
      if (item) {
        item.screen = viewWrapper.screen
        
        // Apply any additional properties from config
        const props = viewWrapper.viewModel.properties;
        for (const key in props) {
          if (props.hasOwnProperty(key)) {
            item[key] = props[key];
          }
        }
      }
    }
  }
}
