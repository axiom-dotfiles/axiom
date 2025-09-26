import QtQuick
import QtQuick.Layouts
import Quickshell.Services.Notifications  // ADD THIS IMPORT
import qs.config

Rectangle {
  id: root

  property string buttonText
  property int urgency // Matches NotificationUrgency enum
  property alias content: contentLoader.sourceComponent

  signal clicked

  implicitHeight: Widget.height
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

  Loader {
    id: contentLoader
    anchors.centerIn: parent
    sourceComponent: Text {
      text: root.buttonText
      font.family: Appearance.fontFamily
      font.pixelSize: Appearance.fontSize - 2
      color: root.urgency === NotificationUrgency.Critical ? Theme.base00 : Theme.foreground  // FIX: Added root.
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
