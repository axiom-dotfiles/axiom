// qs/components/reusable/StyledVolumeBar.qml
pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import qs.config

Item {
  id: component
  
  // -- Signals --
  signal volumeChanged(real newVolume)
  
  // -- Public API --
  property int orientation: Qt.Vertical
  property real volumeLevel: 0.75
  property bool isMuted: false
  property string iconSource: "\uF028"
  property string labelText: ""
  
  // -- Configurable Appearance --
  // null
  
  // -- Implementation --
  implicitWidth: orientation === Qt.Vertical ? 48 : 160
  implicitHeight: orientation === Qt.Vertical ? 160 : 48
  
  Rectangle {
    id: background
    anchors.fill: parent
    radius: Appearance.borderRadius
    color: component.isMuted ? (Theme.backgroundHighlight || Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.2)) : "transparent"
    
    Behavior on color {
      ColorAnimation {
        duration: 200
      }
    }
  }
  
  ColumnLayout {
    anchors.fill: parent
    anchors.margins: 8
    spacing: 8
    
    Rectangle {
      id: barContainer
      Layout.fillWidth: true
      Layout.fillHeight: true
      Layout.alignment: Qt.AlignHCenter
      
      implicitWidth: component.orientation === Qt.Vertical ? 12 : 120
      implicitHeight: component.orientation === Qt.Vertical ? 120 : 12
      
      radius: Appearance.borderRadius
      color: Qt.rgba(Theme.foreground.r, Theme.foreground.g, Theme.foreground.b, 0.2)
      
      Rectangle {
        id: barFill
        anchors.left: component.orientation === Qt.Horizontal ? parent.left : undefined
        anchors.bottom: parent.bottom
        anchors.right: component.orientation === Qt.Vertical ? parent.right : undefined
        anchors.leftMargin: component.orientation === Qt.Vertical ? parent.width - width : 0
        
        width: component.orientation === Qt.Horizontal ? parent.width * component.volumeLevel : parent.width
        height: component.orientation === Qt.Vertical ? parent.height * component.volumeLevel : parent.height
        
        radius: Appearance.borderRadius
        color: component.isMuted ? Qt.rgba(Theme.foreground.r, Theme.foreground.g, Theme.foreground.b, 0.4) : Theme.accent
        
        Behavior on height {
          enabled: component.orientation === Qt.Vertical
          NumberAnimation {
            duration: 150
            easing.type: Easing.OutCubic
          }
        }
        
        Behavior on width {
          enabled: component.orientation === Qt.Horizontal
          NumberAnimation {
            duration: 150
            easing.type: Easing.OutCubic
          }
        }
      }
      
      MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        
        function updateVolume(mousePoint) {
          var newVol = 0.0;
          if (component.orientation === Qt.Vertical) {
            newVol = 1.0 - (mousePoint.y / height);
          } else {
            newVol = mousePoint.x / width;
          }
          component.volumeChanged(Math.max(0.0, Math.min(1.0, newVol)));
        }
        
        onPressed: updateVolume(mouse)
        onPositionChanged: (mouse) => { if (pressed) updateVolume(mouse) }
      }
    }
    
    Item {
      id: iconContainer
      Layout.alignment: Qt.AlignHCenter
      width: iconText.width
      height: iconText.height
      
      Text {
        id: iconText
        text: component.iconSource
        color: Theme.foreground
        font.family: "Symbols Nerd Font"
        font.pixelSize: 24
        anchors.centerIn: parent
      }
      
      Rectangle {
        id: crossOutLine
        anchors.centerIn: parent
        width: parent.width * 1.2
        height: 2
        rotation: 45
        color: Theme.foreground
        radius: 1
        visible: component.isMuted
      }
    }
    
    Text {
      text: component.labelText
      color: Theme.foreground
      font.pixelSize: 12
      Layout.alignment: Qt.AlignHCenter
      visible: text !== ""
      elide: Text.ElideRight
      Layout.maximumWidth: parent.width - 4
    }
  }
}
