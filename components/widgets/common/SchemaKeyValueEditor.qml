// SchemaKeyValueEditor.qml
pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import qs.config
import qs.components.reusable

ColumnLayout {
  id: root
  required property string label
  required property var pairs
  property string description: ""
  property string keyPlaceholder: "Key"
  property string valuePlaceholder: "Value"
  property var keyPattern: null
  
  signal pairAdded(string key, string value)
  signal pairRemoved(string key)
  signal pairChanged(string key, string newValue)
  
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
    spacing: Widget.spacing / 2
    
    Repeater {
      model: Object.keys(root.pairs)
      
      delegate: StyledContainer {
        required property string modelData
        
        Layout.fillWidth: true
        Layout.preferredHeight: Widget.height
        
        RowLayout {
          anchors.fill: parent
          anchors.margins: 4
          spacing: 4
          
          StyledContainer {
            Layout.fillWidth: true
            Layout.preferredHeight: parent.height - 8
            backgroundColor: Theme.background
            
            StyledText {
              anchors.fill: parent
              anchors.leftMargin: Widget.padding / 2
              anchors.rightMargin: Widget.padding / 2
              text: parent.parent.parent.modelData
              textColor: Theme.accent
              textSize: Appearance.fontSize - 1
              verticalAlignment: Text.AlignVCenter
              elide: Text.ElideRight
              font.bold: true
            }
          }
          
          StyledText {
            text: "→"
            opacity: 0.5
          }
          
          StyledContainer {
            Layout.fillWidth: true
            Layout.preferredHeight: parent.height - 8
            backgroundColor: Theme.background
            
            TextInput {
              id: valueInput
              anchors.fill: parent
              anchors.leftMargin: Widget.padding / 2
              anchors.rightMargin: Widget.padding / 2
              text: root.pairs[parent.parent.parent.modelData]
              color: Theme.foreground
              font.family: Appearance.fontFamily
              font.pixelSize: Appearance.fontSize - 1
              verticalAlignment: Text.AlignVCenter
              clip: true
              selectByMouse: true
              
              onTextChanged: {
                root.pairChanged(parent.parent.parent.modelData, text);
              }
            }
          }
          
          StyledRectButton {
            Layout.preferredWidth: parent.height - 8
            Layout.preferredHeight: parent.height - 8
            Layout.fillWidth: false
            Layout.fillHeight: false
            iconText: "×"
            iconSize: 16
            hoverColor: Theme.error
            
            onClicked: {
              root.pairRemoved(parent.parent.parent.modelData);
            }
          }
        }
      }
    }
  }
  
  StyledContainer {
    Layout.fillWidth: true
    Layout.preferredHeight: Widget.height + 8
    backgroundColor: Theme.background
    
    RowLayout {
      anchors.fill: parent
      anchors.margins: 4
      spacing: 4
      
      StyledContainer {
        Layout.fillWidth: true
        Layout.preferredHeight: parent.height
        
        TextInput {
          id: newKeyInput
          anchors.fill: parent
          anchors.leftMargin: Widget.padding / 2
          anchors.rightMargin: Widget.padding / 2
          color: Theme.foreground
          font.family: Appearance.fontFamily
          font.pixelSize: Appearance.fontSize - 1
          verticalAlignment: Text.AlignVCenter
          clip: true
          selectByMouse: true
          
          StyledText {
            visible: !newKeyInput.text && !newKeyInput.activeFocus
            text: root.keyPlaceholder
            opacity: 0.5
            anchors.verticalCenter: parent.verticalCenter
          }
        }
      }
      
      StyledText {
        text: "→"
        opacity: 0.5
      }
      
      StyledContainer {
        Layout.fillWidth: true
        Layout.preferredHeight: parent.height
        
        TextInput {
          id: newValueInput
          anchors.fill: parent
          anchors.leftMargin: Widget.padding / 2
          anchors.rightMargin: Widget.padding / 2
          color: Theme.foreground
          font.family: Appearance.fontFamily
          font.pixelSize: Appearance.fontSize - 1
          verticalAlignment: Text.AlignVCenter
          clip: true
          selectByMouse: true
          
          StyledText {
            visible: !newValueInput.text && !newValueInput.activeFocus
            text: root.valuePlaceholder
            opacity: 0.5
            anchors.verticalCenter: parent.verticalCenter
          }
        }
      }
      
      StyledRectButton {
        Layout.preferredWidth: parent.height
        Layout.preferredHeight: parent.height
        Layout.fillWidth: false
        Layout.fillHeight: false
        iconText: "+"
        iconSize: 18
        hoverColor: Theme.accent
        enabled: newKeyInput.text !== "" && newValueInput.text !== ""
        opacity: enabled ? 1.0 : 0.5
        
        onClicked: {
          if (root.keyPattern === null || new RegExp(root.keyPattern).test(newKeyInput.text)) {
            root.pairAdded(newKeyInput.text, newValueInput.text);
            newKeyInput.text = "";
            newValueInput.text = "";
          }
        }
      }
    }
  }
  
  StyledText {
    visible: Object.keys(root.pairs).length === 0
    text: "No entries - add one above"
    opacity: 0.5
    textSize: Appearance.fontSize - 1
    Layout.fillWidth: true
    horizontalAlignment: Text.AlignHCenter
  }
}
