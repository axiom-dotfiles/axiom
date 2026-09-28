import QtQuick
import QtQuick.Layouts
import qs.config

// One button of a segmented choice laid out in a RowLayout (Dark/Light,
// a wallpaper mode): the chosen one is filled with the accent; one that
// can't be chosen is dimmed
StyledTextButton {
  property bool active: false
  property bool available: true

  Layout.fillWidth: true
  Layout.preferredHeight: Widget.height
  enabled: available
  opacity: available ? 1 : 0.4
  backgroundColor: active ? Theme.accent : Theme.backgroundHighlight
  textColor: active ? Theme.background : Theme.foreground
  hoverColor: active ? Theme.accent : Theme.backgroundAlt
  textHoverColor: active ? Theme.background : Theme.foreground
}
