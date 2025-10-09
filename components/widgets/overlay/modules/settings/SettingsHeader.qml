pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import qs.config

Rectangle {
  Layout.fillWidth: true
  Layout.preferredHeight: Widget.height + Widget.padding
  color: "transparent"

  RowLayout {
    anchors.fill: parent
    spacing: Widget.spacing

    Text {
      text: "Settings"
      color: Theme.foreground
      font.family: Appearance.fontFamily
      font.pixelSize: Appearance.fontSize + 4
      font.bold: true
    }

    Item {
      Layout.fillWidth: true
    }

    // Stage/Unstage/Save buttons
    RowLayout {
      spacing: 4
      visible: root.isDirty || root.isStaged

      // Single stage button (when not staged)
      Rectangle {
        Layout.preferredWidth: 80
        Layout.preferredHeight: Widget.height - 4
        color: stageArea.containsMouse ? Qt.lighter(Theme.info, 1.1) : Theme.info
        radius: Appearance.borderRadius
        visible: root.isDirty && !root.isStaged

        RowLayout {
          anchors.centerIn: parent
          spacing: 6

          Text {
            text: "" // Stage icon
            font.pixelSize: Appearance.fontSize
            color: Theme.background
          }

          Text {
            text: "Stage"
            color: Theme.background
            font.family: Appearance.fontFamily
            font.pixelSize: Appearance.fontSize - 1
            font.bold: true
          }
        }

        MouseArea {
          id: stageArea
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: root.stageChanges()
        }
      }

      // Unstage button (when staged)
      Rectangle {
        Layout.preferredWidth: 40
        Layout.preferredHeight: Widget.height - 4
        color: unstageArea.containsMouse ? Qt.lighter(Theme.backgroundHighlight, 1.2) : Theme.backgroundHighlight
        radius: Appearance.borderRadius
        border.color: Theme.border
        border.width: 1
        visible: root.isStaged

        Text {
          anchors.centerIn: parent
          text: "" // X icon
          font.pixelSize: Appearance.fontSize + 2
          color: Theme.foreground
        }

        MouseArea {
          id: unstageArea
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: root.unstageChanges()
        }
      }

      // Save button (when staged)
      Rectangle {
        Layout.preferredWidth: 80
        Layout.preferredHeight: Widget.height - 4
        color: saveArea.containsMouse ? Qt.lighter(Theme.accent, 1.1) : Theme.accent
        radius: Appearance.borderRadius
        visible: root.isStaged

        RowLayout {
          anchors.centerIn: parent
          spacing: 6

          Text {
            text: "" // Checkmark icon
            font.pixelSize: Appearance.fontSize
            color: Theme.background
          }

          Text {
            text: "Save"
            color: Theme.background
            font.family: Appearance.fontFamily
            font.pixelSize: Appearance.fontSize - 1
            font.bold: true
          }
        }

        MouseArea {
          id: saveArea
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: root.saveChanges()
        }
      }
    }

    // Reset button
    Rectangle {
      Layout.preferredWidth: 80
      Layout.preferredHeight: Widget.height - 4
      color: Theme.backgroundHighlight
      radius: Appearance.borderRadius
      border.color: resetArea.containsMouse ? Theme.accent : Theme.border
      border.width: 1

      RowLayout {
        anchors.fill: parent
        anchors.margins: 4
        spacing: 6

        Text {
          text: "" // Reset icon
          font.pixelSize: Appearance.fontSize
          color: Theme.foreground
          Layout.alignment: Qt.AlignCenter
        }

        Text {
          text: "Reset"
          color: Theme.foreground
          font.family: Appearance.fontFamily
          font.pixelSize: Appearance.fontSize - 1
          Layout.alignment: Qt.AlignCenter
        }
      }

      MouseArea {
        id: resetArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.resetChanges()
      }
    }
  }
}
