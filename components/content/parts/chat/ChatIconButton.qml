import QtQuick
import QtQuick.Layouts
import qs.config
import qs.components.reusable

// The chat's icon button: a fixed square that doesn't stretch in layouts,
// so every button in a row shares one size and centre line
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
