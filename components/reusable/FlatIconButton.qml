pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import qs.config

// A flat icon button (no fill until hovered) of a fixed square size that
// doesn't stretch in layouts, so every button in a row shares one size and
// centre line (the chat's and notes' toolbars)
StyledIconButton {
  property int size: 28

  implicitWidth: size
  implicitHeight: size
  Layout.preferredWidth: size
  Layout.preferredHeight: size
  Layout.fillWidth: false
  Layout.fillHeight: false
  Layout.alignment: Qt.AlignVCenter
  padding: 0
  iconColor: Theme.foregroundAlt
}
