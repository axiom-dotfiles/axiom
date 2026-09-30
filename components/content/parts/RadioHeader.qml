pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import qs.config
import qs.components.reusable

// A radio menu's title row (Wi-Fi, Bluetooth): the title, a refresh icon
// spinning while it scans, and the power switch. Everything is always laid
// out, so the row never shifts.
RowLayout {
  id: root

  property string title: ""
  property bool scanning: false
  property bool checked: false
  property bool switchEnabled: true

  signal toggled(bool checked)

  Layout.fillWidth: true
  Layout.fillHeight: false
  spacing: Widget.spacing

  StyledText {
    Layout.fillWidth: true
    text: root.title
    elide: Text.ElideRight
    font.bold: true
    textColor: Theme.accent
  }

  StyledIcon {
    text: "refresh"
    textColor: Theme.foregroundAlt
    opacity: root.scanning ? 1 : 0

    RotationAnimation on rotation {
      running: root.scanning && Appearance.animations
      loops: Animation.Infinite
      from: 0
      to: 360
      duration: Appearance.animSlow * 4
    }

    Behavior on opacity {
      NumberAnimation {
        duration: Appearance.animFast
      }
    }
  }

  StyledSwitch {
    enabled: root.switchEnabled
    checked: root.checked
    onToggled: root.toggled(checked)
  }
}
