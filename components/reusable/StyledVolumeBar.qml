// qs/components/reusable/StyledVolumeBar.qml
pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import qs.config

Item {
  id: root

  // --- Public API ---
  property int orientation: Qt.Vertical
  property real volumeLevel: 0.75
  // Renamed 'muted' to 'isMuted' for clarity. This is now the primary driver for the muted look.
  property bool isMuted: false
  property string iconSource: "\uF028" // fa-volume-up
  property string labelText: ""

  // Signal emitted when the user clicks or drags on the bar
  signal volumeChanged(real newVolume)

  implicitWidth: orientation === Qt.Vertical ? 48 : 160
  implicitHeight: orientation === Qt.Vertical ? 160 : 48

  // Background to show highlight color when muted/unavailable
  Rectangle {
    id: background
    anchors.fill: parent
    radius: Appearance.borderRadius
    // Use a theme color for highlighting. Add this to your Theme.qml!
    // As a fallback, we use a semi-transparent accent color.
    color: root.isMuted ? (Theme.backgroundHighlight || Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.2)) : "transparent"
    
    Behavior on color { ColorAnimation { duration: 200 } }
  }

  ColumnLayout {
    anchors.fill: parent
    anchors.margins: 8
    spacing: 8

    // The volume bar container (trough)
    Rectangle {
      id: barContainer
      Layout.fillWidth: true
      Layout.fillHeight: true
      Layout.alignment: Qt.AlignHCenter
      
      implicitWidth: root.orientation === Qt.Vertical ? 12 : 120
      implicitHeight: root.orientation === Qt.Vertical ? 120 : 12
      
      radius: Appearance.borderRadius
      color: Qt.rgba(Theme.foreground.r, Theme.foreground.g, Theme.foreground.b, 0.2)

      // The volume bar fill
      Rectangle {
        id: barFill
        anchors.left: root.orientation === Qt.Horizontal ? parent.left : undefined
        anchors.bottom: parent.bottom
        anchors.right: root.orientation === Qt.Vertical ? parent.right : undefined
        anchors.leftMargin: root.orientation === Qt.Vertical ? parent.width - width : 0
        
        width: root.orientation === Qt.Horizontal ? parent.width * root.volumeLevel : parent.width
        height: root.orientation === Qt.Vertical ? parent.height * root.volumeLevel : parent.height

        radius: Appearance.borderRadius
        // A muted bar is grey, otherwise it's the accent color
        color: root.isMuted ? Qt.rgba(Theme.foreground.r, Theme.foreground.g, Theme.foreground.b, 0.4) : Theme.accent

        Behavior on height { enabled: root.orientation === Qt.Vertical; NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
        Behavior on width { enabled: root.orientation === Qt.Horizontal; NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
      }

      // --- Interactivity ---
      MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor

        function updateVolume(mousePoint) {
          var newVol = 0.0;
          if (root.orientation === Qt.Vertical) {
            newVol = 1.0 - (mousePoint.y / height);
          } else {
            newVol = mousePoint.x / width;
          }
          // Clamp value between 0.0 and 1.0 and emit signal
          root.volumeChanged(Math.max(0.0, Math.min(1.0, newVol)));
        }

        onPressed: updateVolume(mouse)
        onPositionChanged: (mouse) => { if (pressed) updateVolume(mouse) }
      }
    }

    // Container for the icon and the cross-out line
    Item {
      id: iconContainer
      Layout.alignment: Qt.AlignHCenter
      width: iconText.width
      height: iconText.height

      // Icon (using a Text item for Nerd Fonts)
      Text {
        id: iconText
        text: root.iconSource
        color: Theme.foreground
        font.family: "Symbols Nerd Font"
        font.pixelSize: 24
        anchors.centerIn: parent
      }

      // --- Muted State Visual: The Cross-Out Line ---
      Rectangle {
        id: crossOutLine
        anchors.centerIn: parent
        width: parent.width * 1.2
        height: 2 // Line thickness
        rotation: 45 // The diagonal angle
        color: Theme.foreground
        radius: 1
        visible: root.isMuted
        
        // Behavior on visible {
        //   OpacityAnimator { from: 0; to: 1.0; duration: 200 }
        // }
      }
    }

    Text {
      text: root.labelText
      color: Theme.foreground
      font.pixelSize: 12
      Layout.alignment: Qt.AlignHCenter
      visible: text !== ""
      elide: Text.ElideRight
      Layout.maximumWidth: parent.width - 4
    }
  }
}
