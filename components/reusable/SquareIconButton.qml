pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import qs.config

// A square icon button of a fixed size that doesn't stretch in layouts
// (StyledRectButton fills by default). Dims when disabled.
StyledRectButton {
  property int size: Widget.height

  Layout.preferredWidth: size
  Layout.preferredHeight: size
  Layout.fillWidth: false
  Layout.fillHeight: false
  opacity: enabled ? 1 : 0.4
  hoverColor: Theme.accent
}
