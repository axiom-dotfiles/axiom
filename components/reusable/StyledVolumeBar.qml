// qs/components/reusable/StyledVolumeBar.qml
pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import qs.config

Item {
  id: root

  // --- Public API ---
  property int orientation: Qt.Vertical // Qt.Vertical or Qt.Horizontal
  property real volumeLevel: 0.75       // Value between 0.0 and 1.0
  property bool muted: false
  property string iconSource: "\uF028"  // Nerd Font volume icon (fa-volume-up)
  property string labelText: ""

  implicitWidth: orientation === Qt.Vertical ? 40 : 150
  implicitHeight: orientation === Qt.Vertical ? 150 : 40

  ColumnLayout {
    anchors.fill: parent
    spacing: 8
    
    // The volume bar container (trough)
    Rectangle {
      id: barContainer
      Layout.fillWidth: true
      Layout.fillHeight: true
      Layout.alignment: Qt.AlignHCenter
      
      // Fixed dimensions for the non-dominant axis
      implicitWidth: root.orientation === Qt.Vertical ? 12 : 120
      implicitHeight: root.orientation === Qt.Vertical ? 120 : 12
      
      radius: 6
      color: Qt.rgba(Theme.foreground.r, Theme.foreground.g, Theme.foreground.b, 0.2) // Trough color

      // The volume bar fill
      Rectangle {
        id: barFill
        
        // Anchoring depends on orientation
        anchors.left: root.orientation === Qt.Horizontal ? parent.left : undefined
        anchors.right: root.orientation === Qt.Vertical ? parent.right : undefined
        anchors.leftMargin: root.orientation === Qt.Vertical ? parent.width - width : 0
        
        anchors.bottom: parent.bottom
        
        width: root.orientation === Qt.Horizontal 
               ? parent.width * root.volumeLevel 
               : parent.width
               
        height: root.orientation === Qt.Vertical 
                ? parent.height * root.volumeLevel 
                : parent.height

        radius: parent.radius
        color: root.muted ? Qt.rgba(Theme.foreground.r, Theme.foreground.g, Theme.foreground.b, 0.5) : Theme.accent

        // Smooth animation for volume changes
        Behavior on height { enabled: root.orientation === Qt.Vertical; NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
        Behavior on width { enabled: root.orientation === Qt.Horizontal; NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
      }
    }

    // Icon (using a Text item for Nerd Fonts)
    Text {
      id: iconText
      text: root.iconSource
      color: Theme.foreground
      font.family: "Symbols Nerd Font" // Make sure you have a Nerd Font available
      font.pixelSize: 24
      Layout.alignment: Qt.AlignHCenter
    }

    // Optional Label
    Text {
      text: root.labelText
      color: Theme.foreground
      font.pixelSize: 12
      Layout.alignment: Qt.AlignHCenter
      visible: text !== ""
      elide: Text.ElideRight
      Layout.maximumWidth: parent.width
    }
  }
}
