// SchemaObjectArray.qml
pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import qs.config
import qs.components.reusable

ColumnLayout {
  id: root
  required property string label
  required property var items
  property string description: ""
  property int maxItems: 99
  property var itemDelegate: null
  
  signal itemAdded()
  signal itemRemoved(int index)
  signal itemMoved(int fromIndex, int toIndex)
  
  Layout.fillWidth: true
  spacing: Widget.spacing
  
  RowLayout {
    Layout.fillWidth: true
    spacing: Widget.spacing
    
    StyledText {
      text: root.label
      textSize: Appearance.fontSize + 1
      font.bold: true
      Layout.fillWidth: true
    }
    
    StyledRectButton {
      visible: root.items.length < root.maxItems
      Layout.preferredWidth: Widget.height
      Layout.preferredHeight: Widget.height
      Layout.fillWidth: false
      Layout.fillHeight: false
      iconText: "+"
      iconSize: Appearance.fontSize + 4
      hoverColor: Theme.accent
      
      onClicked: {
        root.itemAdded();
      }
    }
  }
  
  StyledText {
    visible: root.description !== ""
    text: root.description
    opacity: 0.7
    textSize: Appearance.fontSize - 2
    wrapMode: Text.WordWrap
    Layout.fillWidth: true
  }
  
  ColumnLayout {
    Layout.fillWidth: true
    spacing: Widget.spacing
    
    Repeater {
      model: root.items
      
      delegate: StyledContainer {
        required property int index
        required property var modelData
        
        Layout.fillWidth: true
        implicitHeight: itemContent.implicitHeight + (Widget.padding * 2)
        
        ColumnLayout {
          id: itemContent
          anchors.fill: parent
          anchors.margins: Widget.padding
          spacing: Widget.spacing
          
          RowLayout {
            Layout.fillWidth: true
            spacing: 4
            
            StyledText {
              text: "#" + (parent.parent.parent.index + 1)
              textColor: Theme.accent
              textSize: Appearance.fontSize - 1
              font.bold: true
            }
            
            Item {
              Layout.fillWidth: true
            }
            
            StyledRectButton {
              visible: parent.parent.parent.index > 0
              Layout.preferredWidth: 24
              Layout.preferredHeight: 24
              Layout.fillWidth: false
              Layout.fillHeight: false
              iconText: "▲"
              iconSize: 10
              hoverColor: Theme.accent
              
              onClicked: {
                root.itemMoved(parent.parent.parent.parent.index, parent.parent.parent.parent.index - 1);
              }
            }
            
            StyledRectButton {
              visible: parent.parent.parent.index < root.items.length - 1
              Layout.preferredWidth: 24
              Layout.preferredHeight: 24
              Layout.fillWidth: false
              Layout.fillHeight: false
              iconText: "▼"
              iconSize: 10
              hoverColor: Theme.accent
              
              onClicked: {
                root.itemMoved(parent.parent.parent.parent.index, parent.parent.parent.parent.index + 1);
              }
            }
            
            StyledRectButton {
              Layout.preferredWidth: 24
              Layout.preferredHeight: 24
              Layout.fillWidth: false
              Layout.fillHeight: false
              iconText: "×"
              iconSize: 18
              hoverColor: Theme.error
              
              onClicked: {
                root.itemRemoved(parent.parent.parent.parent.index);
              }
            }
          }
          
          StyledSeparator {
            Layout.fillWidth: true
            separatorHeight: 1
            separatorColor: Theme.border
            opacity: 0.3
          }
          
          Loader {
            Layout.fillWidth: true
            sourceComponent: root.itemDelegate
            onLoaded: {
              item.itemData = Qt.binding(() => parent.parent.parent.modelData);
              item.itemIndex = Qt.binding(() => parent.parent.parent.index);
            }
          }
        }
      }
    }
  }
  
  StyledContainer {
    visible: root.items.length === 0
    Layout.fillWidth: true
    Layout.preferredHeight: 80
    backgroundColor: Theme.background
    
    StyledText {
      anchors.centerIn: parent
      text: "No items - click + to add"
      opacity: 0.5
    }
  }
}
