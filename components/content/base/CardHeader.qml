pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import qs.components.reusable
import qs.config

// Title row of a TitledCard, with Save (shown while `dirty`) and Reset
// buttons for whichever service owns the panel's pending edits. The title
// elides and the buttons drop to icons when the row is too narrow.
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
      id: titleText
      Layout.fillWidth: true
      text: root.title
      textSize: Appearance.fontSize + 4
      font.bold: true
      elide: Text.ElideRight
    }

    SaveResetActions {
      visible: root.showActions
      dirty: root.dirty
      canSave: root.canSave
      saveLabel: root.saveLabel
      compact: root.width < titleText.implicitWidth + headerRow.spacing + fullWidth
      onSave: root.save()
      onReset: root.reset()
    }
  }
}
