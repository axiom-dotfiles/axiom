pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import qs.config
import qs.components.reusable

// A muted icon over a line of text, for a module with nothing to show
// ("All caught up", "No paired devices"). Centre it in the free space.
ColumnLayout {
  id: root

  property string icon: ""
  property string text: ""
  // Widest the text may be before it wraps
  property real maxWidth: 220

  spacing: Widget.spacing / 2
  opacity: 0.55

  StyledIcon {
    visible: root.icon !== ""
    Layout.alignment: Qt.AlignHCenter
    text: root.icon
    textSize: Appearance.fontSize * 2
  }
  StyledText {
    visible: root.text !== ""
    Layout.alignment: Qt.AlignHCenter
    Layout.maximumWidth: root.maxWidth
    horizontalAlignment: Text.AlignHCenter
    wrapMode: Text.WordWrap
    text: root.text
    textSize: Appearance.fontSize - 1
  }
}
