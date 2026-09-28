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
  property string iconSource: "volume_up"
  property string labelText: ""
  // Shows the level as a percentage (in place of labelText)
  property bool showPercent: false
  // Level change per wheel notch (0-1); 0 turns scrolling off
  property real scrollStep: 0

  // -- Configurable Appearance --
  // null

  // -- Implementation --
  // Wide enough for "100%" under the icon
  implicitWidth: orientation === Qt.Vertical ? Math.max(48, showPercent ? widest.advanceWidth + 16 : 0) : 160
  implicitHeight: orientation === Qt.Vertical ? 160 : 48

  // Anywhere on the bar; a notch is 120, so touchpads step smoothly
  WheelHandler {
    enabled: component.enabled && component.scrollStep > 0
    acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
    onWheel: event => {
      const delta = event.angleDelta.y !== 0 ? event.angleDelta.y : -event.angleDelta.x;
      const level = component.volumeLevel + component.scrollStep * delta / 120;
      component.volumeChanged(Math.round(Math.max(0, Math.min(1, level)) * 100) / 100);
    }
  }

  Rectangle {
    id: background
    anchors.fill: parent
    radius: Appearance.borderRadius
    color: component.isMuted ? (Theme.backgroundHighlight || Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.2)) : "transparent"

    Behavior on color {
      ColorAnimation {
        duration: Appearance.animNormal
      }
    }
  }

  // Vertical: bar above the icon. Horizontal: icon left of the bar (a
  // column there would squeeze the bar to nothing in the 48px height).
  GridLayout {
    id: content
    readonly property bool isVertical: component.orientation === Qt.Vertical

    anchors.fill: parent
    anchors.margins: 8
    rowSpacing: 8
    columnSpacing: 8

    Rectangle {
      id: barContainer
      Layout.row: 0
      Layout.column: content.isVertical ? 0 : 1
      Layout.fillWidth: true
      Layout.fillHeight: true
      Layout.alignment: Qt.AlignCenter

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
            duration: Appearance.animNormal
            easing.type: Easing.OutCubic
          }
        }

        Behavior on width {
          enabled: component.orientation === Qt.Horizontal
          NumberAnimation {
            duration: Appearance.animNormal
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
        onPositionChanged: mouse => {
          if (pressed)
            updateVolume(mouse);
        }
      }
    }

    Item {
      id: iconContainer
      Layout.row: content.isVertical ? 1 : 0
      Layout.column: 0
      Layout.alignment: Qt.AlignCenter
      width: iconText.width
      height: iconText.height

      StyledIcon {
        id: iconText
        text: component.iconSource
        color: Theme.foreground
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

    StyledText {
      text: component.showPercent ? Math.round(component.volumeLevel * 100) + "%" : component.labelText
      textSize: 12
      horizontalAlignment: Text.AlignHCenter
      Layout.row: content.isVertical ? 2 : 0
      Layout.column: content.isVertical ? 0 : 2
      Layout.alignment: Qt.AlignCenter
      // A fixed width for percentages, so the bar doesn't shift as it changes
      Layout.preferredWidth: component.showPercent ? widest.advanceWidth : -1
      visible: text !== ""
      elide: Text.ElideRight
      Layout.maximumWidth: component.showPercent ? Infinity : parent.width - 4

      TextMetrics {
        id: widest
        font.family: Appearance.fontFamily
        font.pixelSize: 12
        text: "100%"
      }
    }
  }
}
