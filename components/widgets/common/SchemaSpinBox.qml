// SchemaSpinBox.qml
pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import qs.config
import qs.components.reusable

ColumnLayout {
  id: root
  required property string label
  required property int value
  property string description: ""
  property int minimum: 0
  property int maximum: 999
  property int stepSize: 1

  Layout.fillWidth: true
  spacing: 4

  StyledText {
    text: root.label
    Layout.fillWidth: true
  }

  StyledContainer {
    Layout.fillWidth: true
    Layout.preferredHeight: Widget.height

    RowLayout {
      anchors.fill: parent
      anchors.margins: 4
      spacing: 4

      StyledRectButton {
        Layout.preferredWidth: Widget.height - 8
        Layout.preferredHeight: Widget.height - 8
        Layout.fillWidth: false
        Layout.fillHeight: false
        iconText: "−"
        iconSize: Appearance.fontSize + 4

        onClicked: {
          if (spinBox.value > root.minimum) {
            spinBox.value = spinBox.value - root.stepSize;
          }
        }
      }

      SpinBox {
        id: spinBox
        Layout.fillWidth: true
        from: root.minimum
        to: root.maximum
        value: root.value
        stepSize: root.stepSize
        editable: true

        background: Item {}

        contentItem: TextInput {
          text: spinBox.textFromValue(spinBox.value, spinBox.locale)
          color: Theme.foreground
          font.family: Appearance.fontFamily
          font.pixelSize: Appearance.fontSize
          horizontalAlignment: Text.AlignHCenter
          verticalAlignment: Text.AlignVCenter
          readOnly: !spinBox.editable
          validator: spinBox.validator
          inputMethodHints: Qt.ImhDigitsOnly
          selectByMouse: true
        }

        onValueModified: {
          root.valueChanged(value);
        }
      }

      StyledRectButton {
        Layout.preferredWidth: Widget.height - 8
        Layout.preferredHeight: Widget.height - 8
        Layout.fillWidth: false
        Layout.fillHeight: false
        iconText: "+"
        iconSize: Appearance.fontSize + 4

        onClicked: {
          if (spinBox.value < root.maximum) {
            spinBox.value = spinBox.value + root.stepSize;
          }
        }
      }
    }
  }

  StyledText {
    visible: root.description !== ""
    text: root.description
    opacity: 0.7
    textSize: Appearance.fontSize - 2
    wrapMode: Text.WordWrap
    Layout.fillWidth: true
  }
}
