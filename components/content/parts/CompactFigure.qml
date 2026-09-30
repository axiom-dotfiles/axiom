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

  FigureValue {
    visible: root.value !== ""
    Layout.alignment: Qt.AlignHCenter
    value: root.value
    unit: root.unit
    valueColor: root.valueColor
    valueSize: Appearance.fontSize * 1.8
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
