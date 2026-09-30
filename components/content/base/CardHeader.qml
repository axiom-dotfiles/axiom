pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import qs.components.reusable
import qs.config

// Title row of a TitledCard, with Save (shown while `dirty`) and Reset
// buttons for whichever service owns the panel's pending edits
Rectangle {
  id: root
  property string title
  property bool dirty: false
  // Hide both buttons for panels with nothing to save
  property bool showActions: true
  // Save stays visible while dirty but is disabled when false
  property bool canSave: true
  property string saveLabel: I18n.tr("Save")

  signal save
  signal reset

  Layout.fillWidth: true
  Layout.preferredHeight: Math.max(Widget.height + Widget.padding, headerRow.implicitHeight)
  color: "transparent"

  RowLayout {
    id: headerRow
    anchors.fill: parent
    spacing: Widget.spacing

    StyledText {
      text: root.title
      textSize: Appearance.fontSize + 4
      font.bold: true
    }

    Item {
      Layout.fillWidth: true
    }

    HeaderButton {
      visible: root.showActions && root.dirty
      enabled: root.canSave
      icon: "check"
      label: root.saveLabel
      fillColor: hovered ? Qt.lighter(Theme.accent, 1.1) : Theme.accent
      contentColor: Theme.background
      onClicked: root.save()
    }

    HeaderButton {
      visible: root.showActions
      icon: "undo"
      label: I18n.tr("Reset")
      fillColor: Theme.backgroundHighlight
      strokeColor: hovered ? Theme.accent : Theme.border
      contentColor: Theme.foreground
      onClicked: root.reset()
    }
  }
  // Sized to its label (translations differ in width, and fonts in height),
  // at least `minWidth` so Save and Reset line up in English
  component HeaderButton: Rectangle {
    id: button

    property string icon
    property string label
    property color fillColor
    property color strokeColor: "transparent"
    property color contentColor
    readonly property bool hovered: area.containsMouse
    readonly property int minWidth: 80

    signal clicked

    Layout.preferredWidth: Math.max(button.minWidth, buttonRow.implicitWidth + Widget.padding * 2)
    Layout.preferredHeight: Math.max(Widget.height - 4, buttonRow.implicitHeight + 8)
    color: button.fillColor
    radius: Widget.radius
    border.color: button.strokeColor
    border.width: 1
    opacity: button.enabled ? 1 : 0.4

    RowLayout {
      id: buttonRow
      anchors.centerIn: parent
      spacing: 6

      StyledIcon {
        text: button.icon
        textSize: Appearance.fontSize
        textColor: button.contentColor
        Layout.alignment: Qt.AlignVCenter
      }

      StyledText {
        text: button.label
        textSize: Appearance.fontSize - 1
        textColor: button.contentColor
        font.bold: true
        Layout.alignment: Qt.AlignVCenter
      }
    }

    MouseArea {
      id: area
      anchors.fill: parent
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      onClicked: button.clicked()
    }
  }
}
