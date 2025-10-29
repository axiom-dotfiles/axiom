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
  property alias placeholderText: textInput.placeholderText
  property alias input: textInput
  property alias readOnly: textInput.readOnly
  property alias wantsKeyboardFocus: textInput.activeFocus
  property bool expandable: false
  
  signal accepted
  signal boxClicked
  
  implicitHeight: {
    if (!expandable) return textInput.implicitHeight + 20
    
    var minHeight = 40
    var contentBasedHeight = textInput.contentHeight + 30  // 10px top + 10px bottom margins
    
    return Math.max(minHeight, contentBasedHeight)
  }
  
  borderColor: textInput.activeFocus ? Theme.accent : Theme.border
  backgroundColor: Theme.backgroundAlt
  
  Behavior on borderColor {
    ColorAnimation { duration: 200; easing.type: Easing.InOutQuad }
  }
  
  Behavior on implicitHeight {
    NumberAnimation { duration: 150; easing.type: Easing.InOutQuad }
  }
  
  Flickable {
    id: flickable
    anchors.fill: parent
    anchors.leftMargin: 10
    anchors.rightMargin: 10
    anchors.topMargin: control.expandable ? 10 : 0
    anchors.bottomMargin: control.expandable ? 10 : 0
    
    contentWidth: textInput.contentWidth
    contentHeight: textInput.contentHeight
    clip: true
    
    // Only enable scrolling in expandable mode
    interactive: control.expandable
    
    TextArea {
      id: textInput
      width: flickable.width
      text: control.text
      onTextChanged: control.text = text
      
      // --- Core Properties ---
      color: Theme.foreground
      font.family: Appearance.fontFamily
      font.pixelSize: Appearance.fontSize
      selectByMouse: true
      selectedTextColor: Theme.background
      selectionColor: Theme.accent
      wrapMode: control.expandable ? TextEdit.Wrap : TextEdit.NoWrap
      
      // --- Placeholder Properties ---
      placeholderTextColor: Qt.rgba(
        Theme.foreground.r,
        Theme.foreground.g,
        Theme.foreground.b,
        0.5
      )
      
      // Handle Enter/Return key
      Keys.onPressed: (event) => {
        if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
          if (control.expandable && (event.modifiers & Qt.ShiftModifier)) {
            // Shift+Enter in expandable mode: insert newline (default behavior)
            event.accepted = false
          } else if (!control.expandable) {
            // Enter in non-expandable mode: emit accepted
            control.accepted()
            event.accepted = true
          } else {
            // Enter in expandable mode without Shift: emit accepted
            control.accepted()
            event.accepted = true
          }
        }
      }
      
      background: Rectangle {
        color: "transparent"
      }
      
      // Custom cursor for consistency with your original design
      cursorDelegate: Rectangle {
        width: 2
        color: Theme.accent
        visible: textInput.activeFocus
        
        SequentialAnimation on opacity {
          loops: Animation.Infinite
          running: textInput.activeFocus
          PropertyAnimation { to: 1; duration: 500 }
          PropertyAnimation { to: 0; duration: 500 }
        }
      }
    }
  }
}
