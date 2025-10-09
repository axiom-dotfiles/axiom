// SchemaComboBox.qml
pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects
import qs.config
import qs.components.reusable

ColumnLayout {
  id: root
  required property string label
  required property var options
  required property string currentValue
  property string description: ""
  
  signal selectionChanged(string newValue)
  
  Layout.fillWidth: true
  spacing: 4
  
  StyledText {
    text: root.label
    Layout.fillWidth: true
  }
  
  StyledContainer {
    id: comboContainer
    Layout.fillWidth: true
    Layout.preferredHeight: Widget.height
    borderColor: comboBox.popup.visible ? Theme.accent : Theme.border
    
    RowLayout {
      anchors.fill: parent
      anchors.leftMargin: Widget.padding
      anchors.rightMargin: Widget.padding
      spacing: 0
      
      StyledText {
        text: root.currentValue
        Layout.fillWidth: true
        elide: Text.ElideRight
      }
      
      StyledText {
        text: "▾"
        textColor: Theme.accent
        textSize: Appearance.fontSize + 2
        Layout.preferredWidth: implicitWidth
      }
    }
    
    ComboBox {
      id: comboBox
      anchors.fill: parent
      model: root.options
      currentIndex: root.options.indexOf(root.currentValue)
      
      background: Item {}
      contentItem: Item {}
      indicator: Item {}
      
      onActivated: (index) => {
        root.selectionChanged(root.options[index]);
      }
      
      popup: Popup {
        y: comboContainer.height + 4
        width: comboContainer.width
        padding: 0
        
        background: StyledContainer {
          backgroundColor: Theme.background
          borderColor: Theme.border
          
          layer.enabled: true
          layer.effect: DropShadow {
            transparentBorder: true
            horizontalOffset: 0
            verticalOffset: 2
            radius: 8
            samples: 17
            color: "#40000000"
          }
        }
        
        contentItem: ListView {
          clip: true
          implicitHeight: contentHeight
          model: comboBox.popup.visible ? comboBox.delegateModel : null
          currentIndex: comboBox.highlightedIndex
          
          ScrollIndicator.vertical: ScrollIndicator {}
        }
      }
      
      delegate: Rectangle {
        required property int index
        required property string modelData
        
        width: comboBox.width
        height: Widget.height
        color: delegateArea.containsMouse ? Theme.backgroundHighlight : "transparent"
        
        StyledText {
          anchors.fill: parent
          anchors.leftMargin: Widget.padding
          anchors.rightMargin: Widget.padding
          text: parent.modelData
          verticalAlignment: Text.AlignVCenter
          elide: Text.ElideRight
        }
        
        MouseArea {
          id: delegateArea
          anchors.fill: parent
          hoverEnabled: true
          onClicked: {
            comboBox.currentIndex = parent.index;
            comboBox.activated(parent.index);
            comboBox.popup.close();
          }
        }
      }
    }
    
    MouseArea {
      anchors.fill: parent
      onClicked: {
        comboBox.popup.open();
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
}
