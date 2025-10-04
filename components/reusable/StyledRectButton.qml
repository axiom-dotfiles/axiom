// qs/components/reusable/StyledRectButton.qml
pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.config
import qs.components.reusable

Rectangle {
  id: component
  
  // -- Signals --
  signal clicked()
  
  // -- Public API --
  property string iconText: ""
  property string tooltipText: ""
  
  // -- Configurable Appearance --
  property alias iconSize: iconLabel.textSize
  property alias iconColor: iconLabel.textColor
  property color backgroundColor: Theme.backgroundAlt
  property color hoverColor: component.backgroundColor
  property color pressColor: component.backgroundColor
  property color borderColor: "transparent"
  property color borderHoverColor: component.borderColor
  property color borderPressColor: component.borderColor
  property int borderWidth: Appearance.borderWidth
  property real borderRadius: Appearance.borderRadius
  
  // -- Implementation --
  Layout.fillHeight: true
  Layout.fillWidth: true
  Layout.alignment: Qt.AlignHCenter | Qt.AlignVCenter
  implicitWidth: Bar.extent - (Widget.padding * 2)
  implicitHeight: Bar.extent - (Widget.padding * 2)
  width: implicitWidth
  height: implicitHeight
  
  color: mouseArea.pressed ? component.pressColor : 
         (mouseArea.containsMouse ? component.hoverColor : component.backgroundColor)
  border.color: mouseArea.pressed ? component.borderPressColor :
                (mouseArea.containsMouse ? component.borderHoverColor : component.borderColor)
  border.width: component.borderWidth
  radius: component.borderRadius
  
  Behavior on color {
    ColorAnimation {
      duration: 150
    }
  }
  
  Behavior on border.color {
    ColorAnimation {
      duration: 150
    }
  }
  
  StyledText {
    id: iconLabel
    anchors.centerIn: parent
    text: component.iconText
    textSize: Appearance.fontSize
    textColor: Theme.foreground
  }
  
  MouseArea {
    id: mouseArea
    anchors.fill: parent
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    onClicked: component.clicked()
  }
  
  ToolTip {
    id: tooltip
    text: component.tooltipText
    visible: false
    delay: 500
  }
}
