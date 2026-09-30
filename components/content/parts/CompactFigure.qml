pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import qs.config
import qs.components.reusable

// What a quarter-card slot shows: an icon over one big value and a small
// label, centred in the slot. Put it in a Card's compact branch or a
// Panel's compactContent.
ColumnLayout {
  id: root

  property string icon: ""
  property string value: ""
  property string unit: ""
  property string label: ""
  property color iconColor: Theme.accent
  property color valueColor: Theme.foreground
  // Widest the label may be (it elides past this)
  property real maxWidth: 160

  spacing: 0

  StyledIcon {
    visible: root.icon !== ""
    Layout.alignment: Qt.AlignHCenter
    Layout.bottomMargin: Widget.spacing / 2
    text: root.icon
    textColor: root.iconColor
    textSize: Appearance.fontSize * 1.8
  }

  RowLayout {
    visible: root.value !== ""
    Layout.alignment: Qt.AlignHCenter
    spacing: 2
    StyledText {
      text: root.value
      textColor: root.valueColor
      textSize: Appearance.fontSize * 1.8
      font.bold: true
    }
    StyledText {
      visible: root.unit !== ""
      Layout.alignment: Qt.AlignBaseline
      text: root.unit
      opacity: 0.7
    }
  }

  StyledText {
    visible: root.label !== ""
    Layout.alignment: Qt.AlignHCenter
    Layout.maximumWidth: root.maxWidth
    horizontalAlignment: Text.AlignHCenter
    elide: Text.ElideRight
    text: root.label
    textSize: Appearance.fontSize - 2
    opacity: 0.6
  }
}
