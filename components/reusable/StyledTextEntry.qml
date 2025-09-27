// components/reusable/StyledTextEntry.qml
pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls // This import is essential for TextField
import Quickshell.Wayland

import qs.config

StyledContainer {
  id: control

  // --- Public API ---
  property alias text: textField.text
  property alias placeholderText: textField.placeholderText // This is now a valid alias
  property alias input: textField
  property alias acceptableInput: textField.validator
  property alias readOnly: textField.readOnly
  signal accepted

  // --- Internal Implementation ---
  implicitHeight: textField.implicitHeight + 20
  containerBorderColor: textField.activeFocus ? Theme.accent : Theme.border
  containerColor: Theme.backgroundAlt
  containerBorderWidth: Appearance.borderWidth
  containerRadius: Appearance.borderRadius

  Behavior on containerBorderColor {
    ColorAnimation { duration: 200; easing.type: Easing.InOutQuad }
  }

  // Use TextField for robust placeholder support and modern styling capabilities.
  TextField {
    id: textField // Renamed from textInput for clarity
    anchors.fill: parent
    anchors.leftMargin: 10
    anchors.rightMargin: 10
    verticalAlignment: TextInput.AlignVCenter

    // --- Core Properties ---
    color: Theme.foreground
    font.family: Appearance.fontFamily
    font.pixelSize: Appearance.fontSize
    selectByMouse: true
    selectedTextColor: Theme.background
    selectionColor: Theme.accent

    // --- Placeholder Properties ---
    // placeholderText is aliased from the parent control.
    placeholderTextColor: Qt.tint(Theme.foreground, "#808080")

    // --- Behavior ---
    onAccepted: control.accepted()

    // --- Styling ---
    // The StyledContainer provides the background and border, so we make
    // the TextField's own background transparent.
    background: Rectangle {
        color: "transparent"
    }

    // A custom cursor is good for theming.
    cursorDelegate: Rectangle {
      width: 2
      color: Theme.accent
      visible: textField.activeFocus
    }
  }
}
