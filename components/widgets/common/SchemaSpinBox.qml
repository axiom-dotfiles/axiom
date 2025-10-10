// SchemaSpinBox.qml
pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import qs.config
import qs.components.reusable

ColumnLayout {
  id: root
  required property int currentConfigValue
  property int minimum: 0
  property int maximum: 999
  property int stepSize: 1
  property alias value: spinBox.value
  property bool isDirty: (root.value !== root.currentConfigValue)
  
  // Central height control
  property int controlHeight: Widget.height
  readonly property int buttonSize: controlHeight - (containerMargins * 2)
  readonly property int containerMargins: 4
  
  signal dirtied()
  
  onIsDirtyChanged: {
    if (isDirty) {
      root.dirtied();
    }
  }
  
  required property string label
  property string description: ""
  
  onCurrentConfigValueChanged: {
    spinBox.value = root.currentConfigValue;
  }
  
  Layout.fillWidth: true
  spacing: 4
  
  StyledText {
    text: root.label
    Layout.fillWidth: true
  }
  
  StyledContainer {
    Layout.fillWidth: true
    Layout.preferredHeight: root.controlHeight
    
    RowLayout {
      anchors.fill: parent
      anchors.margins: root.containerMargins
      spacing: 4
      
      StyledRectButton {
        Layout.preferredWidth: root.buttonSize
        Layout.preferredHeight: root.buttonSize
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
        Layout.fillHeight: true
        from: root.minimum
        to: root.maximum
        value: root.currentConfigValue
        stepSize: root.stepSize
        editable: true
        background: Item {}
        contentItem: TextInput {
          anchors.fill: parent
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
          root.valueChanged();
        }
      }
      
      StyledRectButton {
        Layout.preferredWidth: root.buttonSize
        Layout.preferredHeight: root.buttonSize
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
