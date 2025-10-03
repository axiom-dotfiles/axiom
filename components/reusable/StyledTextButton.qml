// qs/components/reusable/StyledTextButton.qml
pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import qs.config
import qs.components.reusable

Rectangle {
  id: component
  
  // -- Signals --
  signal clicked()
  
  // -- Public API --
  property alias text: label.text
  
  // -- Configurable Appearance --
  property int textPadding: 8
  property color backgroundColor: Theme.backgroundHighlight
  property color hoverColor: Theme.accent
  property color pressColor: Theme.accentAlt
  property color textColor: Theme.foreground
  property color textHoverColor: Theme.background
  property color borderColor: Theme.border
  property int borderWidth: 0
  property real borderRadius: Appearance.borderRadius
  
  // -- Implementation --
  implicitWidth: label.implicitWidth + (textPadding * 2)
  implicitHeight: label.implicitHeight + textPadding
  Layout.alignment: Qt.AlignVCenter
  
  color: mouseArea.pressed ? pressColor : (mouseArea.containsMouse ? hoverColor : backgroundColor)
  border.color: borderColor
  border.width: borderWidth
  radius: borderRadius
  
  Behavior on color {
    ColorAnimation {
      duration: 150
      easing.type: Easing.InOutQuad
    }
  }
  
  StyledText {
    id: label
    anchors.centerIn: parent
    textColor: mouseArea.containsMouse ? component.textHoverColor : component.textColor
    textSize: Appearance.fontSize
    font.bold: true
    
    Behavior on textColor {
      ColorAnimation {
        duration: 150
        easing.type: Easing.InOutQuad
      }
    }
  }
  
  MouseArea {
    id: mouseArea
    anchors.fill: parent
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    onClicked: component.clicked()
  }
}
