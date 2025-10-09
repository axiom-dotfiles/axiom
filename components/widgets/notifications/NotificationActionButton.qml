import QtQuick
import QtQuick.Layouts
import Quickshell.Services.Notifications
import qs.config

Rectangle {
  id: root

  // For use in Repeater
  property var modelData

  property string buttonText
  property int urgency // Matches NotificationUrgency enum
  property alias content: contentLoader.sourceComponent

  signal clicked

  implicitHeight: 32 // horrendously bad magic number "looks good"
  implicitWidth: contentLoader.item ? contentLoader.item.implicitWidth + (Widget.padding * 2) : 0
  radius: Appearance.borderRadius

  color: {
    const baseColor = urgency === NotificationUrgency.Critical ? Theme.accentAlt : Theme.backgroundHighlight;
    if (mouseArea.pressed)
      return Qt.darker(baseColor, 1.2);
    if (mouseArea.hovered)
      return Qt.lighter(baseColor, 1.1);
    return baseColor;
  }

  Behavior on color {
    enabled: Appearance.animations
    NumberAnimation {
      duration: 100
    }
  }

  Loader {
    id: contentLoader
    anchors.centerIn: parent
    sourceComponent: Text {
      text: root.buttonText
      font.family: Appearance.fontFamily
      font.pixelSize: Appearance.fontSize - 2
      color: root.urgency === NotificationUrgency.Critical ? Theme.base00 : Theme.foreground
      horizontalAlignment: Text.AlignHCenter
      verticalAlignment: Text.AlignVCenter
    }
  }

  MouseArea {
    id: mouseArea
    anchors.fill: parent
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    onClicked: root.clicked()
  }
}
