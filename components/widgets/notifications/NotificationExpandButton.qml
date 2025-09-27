import QtQuick
import QtQuick.Layouts

import qs.config
import qs.components.reusable

StyledContainer {
  id: root

  required property int count
  required property bool expanded

  signal altAction
  signal clicked

  implicitHeight: 28
  implicitWidth: contentRow.implicitWidth + (Widget.padding * 2)
  radius: Appearance.borderRadius

  containerColor: mouseArea.pressed ? Qt.darker(Theme.backgroundHighlight, 1.2) : mouseArea.hovered ? Qt.lighter(Theme.backgroundHighlight, 1.1) : Theme.backgroundHighlight

  Behavior on containerColor {
    enabled: Widget.animations
    NumberAnimation {
      duration: 100
    }
  }

  RowLayout {
    id: contentRow
    anchors.centerIn: parent
    spacing: Widget.spacing / 2

    Text {
      visible: root.count > 1
      text: root.count
      font.family: Appearance.fontFamily
      font.pixelSize: Appearance.fontSize - 2
      font.weight: Font.Bold
      color: Theme.foreground
    }
    Text {
      text: "expand_more"
      font.family: "Material Symbols Outlined"
      font.pixelSize: Appearance.fontSize + 4
      color: Theme.foreground
      rotation: root.expanded ? 180 : 0
      Behavior on rotation {
        enabled: Widget.animations
        NumberAnimation {
          duration: Widget.animationDuration
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
    onClicked: mouse => {
      if (mouse.button === Qt.RightButton) {
        root.altAction();
      } else {
        root.clicked();
      }
    }
  }
}
