// /components/reusable/SizedIconButton.qml
pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import qs.config

Rectangle {
  id: component
  
  // -- Signals --
  signal clicked()
  
  // -- Public API --
  property string iconText: ""
  property string labelText: ""
  
  // -- Configurable Appearance --
  property alias backgroundColor: component.color
  property alias borderColor: component.border.color
  property alias borderWidth: component.border.width
  property alias borderRadius: component.radius
  
  property color hoverColor: Theme.accent
  property color pressColor: Theme.accentAlt
  property color textColor: Theme.foreground
  property color textHoverColor: Theme.background
  
  property int buttonSize: 120
  property int iconSize: 48
  property int labelSize: Appearance.fontSize
  property int spacing: 8
  
  // -- Implementation --
  implicitWidth: buttonSize
  implicitHeight: buttonSize
  Layout.alignment: Qt.AlignCenter
  
  color: mouseArea.pressed ? pressColor : (mouseArea.containsMouse ? hoverColor : backgroundColor)
  border.color: Theme.border
  border.width: Appearance.borderWidth
  radius: Appearance.borderRadius
  
  Behavior on color {
    ColorAnimation {
      duration: 150
      easing.type: Easing.InOutQuad
    }
  }
  
  ColumnLayout {
    anchors.fill: parent
    spacing: component.spacing
    
    StyledText {
      id: icon
      text: component.iconText
      textColor: mouseArea.containsMouse ? component.textHoverColor : component.textColor
      textSize: component.iconSize
      Layout.alignment: Qt.AlignHCenter | Qt.AlignBottom
      Layout.fillWidth: true
      horizontalAlignment: Text.AlignHCenter
      
      Behavior on textColor {
        ColorAnimation {
          duration: 150
          easing.type: Easing.InOutQuad
        }
      }
    }
    
    StyledText {
      id: label
      text: component.labelText
      textColor: mouseArea.containsMouse ? component.textHoverColor : component.textColor
      textSize: component.labelSize
      font.bold: true
      Layout.alignment: Qt.AlignHCenter | Qt.AlignTop
      Layout.fillWidth: true
      horizontalAlignment: Text.AlignHCenter
      
      Behavior on textColor {
        ColorAnimation {
          duration: 150
          easing.type: Easing.InOutQuad
        }
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
