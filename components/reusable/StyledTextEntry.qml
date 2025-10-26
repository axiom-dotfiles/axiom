// components/reusable/StyledTextEntry.qml
pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Window
import Quickshell.Wayland
import qs.config

StyledContainer {
  id: control
  
  // --- Public API ---
  property string text: ""
  property alias placeholderText: textField.placeholderText
  property alias input: textField
  property alias acceptableInput: textField.validator
  property alias readOnly: textField.readOnly
  property alias wantsKeyboardFocus: textField.activeFocus
  
  signal accepted
  signal boxClicked
  
  implicitHeight: textField.implicitHeight + 20
  borderColor: textField.activeFocus ? Theme.accent : Theme.border
  backgroundColor: Theme.backgroundAlt
  
  Behavior on borderColor {
    ColorAnimation { duration: 200; easing.type: Easing.InOutQuad }
  }
  
  TextField {
    id: textField
    anchors.fill: parent
    anchors.leftMargin: 10
    anchors.rightMargin: 10
    verticalAlignment: TextInput.AlignVCenter
    text: control.text
    onTextChanged: control.text = text
    
    // --- Core Properties ---
    color: Theme.foreground
    font.family: Appearance.fontFamily
    font.pixelSize: Appearance.fontSize
    selectByMouse: true
    selectedTextColor: Theme.background
    selectionColor: Theme.accent
    wrapMode: Text.Wrap
    
    // --- Placeholder Properties ---
    placeholderTextColor: Qt.rgba(
      Theme.foreground.r,
      Theme.foreground.g,
      Theme.foreground.b,
      0.5
    )
    
    onAccepted: control.accepted()
    
    background: Rectangle {
      color: "transparent"
    }
    
    cursorDelegate: Rectangle {
      width: 2
      color: Theme.accent
      visible: textField.activeFocus
      
      // Blinking animation
      SequentialAnimation on opacity {
        loops: Animation.Infinite
        running: textField.activeFocus
        PropertyAnimation { to: 1; duration: 500 }
        PropertyAnimation { to: 0; duration: 500 }
      }
    }
  }
}
