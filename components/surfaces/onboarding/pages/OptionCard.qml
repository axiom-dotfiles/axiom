import QtQuick
import QtQuick.Layouts

import qs.config
import qs.components.reusable

// A choice as a box: an icon, a title with an optional "Recommended" tag,
// and a description. The selected one is outlined in the accent color.
Rectangle {
  id: root

  property string icon
  property string title
  property string description
  property bool selected: false
  property bool recommended: false
  // False greys it out and ignores clicks
  property bool available: true

  signal clicked

  Layout.fillWidth: true
  implicitHeight: row.implicitHeight + Widget.padding * 2
  radius: Appearance.borderRadius
  color: root.selected ? Qt.alpha(Theme.accent, 0.12) : area.containsMouse && root.available ? Theme.backgroundHighlight : Theme.backgroundAlt
  border.color: root.selected ? Theme.accent : Theme.border
  border.width: Appearance.borderWidth
  opacity: root.available ? 1 : 0.5

  Behavior on color {
    ColorAnimation {
      duration: Appearance.animFast
    }
  }

  RowLayout {
    id: row
    anchors.fill: parent
    anchors.margins: Widget.padding
    spacing: Widget.padding

    StyledIcon {
      Layout.alignment: Qt.AlignTop
      visible: root.icon !== ""
      text: root.icon
      textSize: Appearance.fontSize * 1.6
      textColor: root.selected ? Theme.accent : Theme.foreground
    }

    ColumnLayout {
      Layout.fillWidth: true
      spacing: Widget.spacing / 2

      RowLayout {
        spacing: Widget.spacing

        StyledText {
          text: root.title
          font.bold: true
        }

        Rectangle {
          visible: root.recommended
          implicitWidth: tag.implicitWidth + Widget.spacing * 2
          implicitHeight: tag.implicitHeight + 4
          radius: height / 2
          color: Theme.accent

          StyledText {
            id: tag
            anchors.centerIn: parent
            text: I18n.tr("Recommended")
            textSize: Appearance.fontSize * 0.8
            textColor: Theme.background
          }
        }
      }

      StyledText {
        Layout.fillWidth: true
        visible: root.description !== ""
        text: root.description
        wrapMode: Text.WordWrap
        textColor: Theme.foregroundAlt
        textSize: Appearance.fontSize * 0.9
      }
    }
  }

  MouseArea {
    id: area
    anchors.fill: parent
    hoverEnabled: true
    enabled: root.available
    cursorShape: Qt.PointingHandCursor
    onClicked: root.clicked()
  }
}
