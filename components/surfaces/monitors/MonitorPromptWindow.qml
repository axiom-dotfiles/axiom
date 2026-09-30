pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland

import qs.components.reusable
import qs.config
import qs.services

// One screen's prompt: its name while MonitorManager identifies, and
// Keep / Revert with the countdown while an applied layout waits
PanelWindow {
  id: root

  readonly property bool asking: MonitorManager.pending
  readonly property bool shown: asking || MonitorManager.identifying
  readonly property int pad: 18

  visible: shown || card.opacity > 0
  color: "transparent"
  exclusionMode: ExclusionMode.Ignore
  implicitWidth: card.width
  implicitHeight: card.height

  WlrLayershell.layer: WlrLayer.Overlay
  WlrLayershell.namespace: "axiom-monitor-prompt"
  WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

  Rectangle {
    id: card

    width: content.implicitWidth + root.pad * 2
    height: content.implicitHeight + root.pad * 2
    color: Theme.background
    border.color: root.asking ? Theme.accent : Theme.border
    border.width: Appearance.borderWidth
    radius: Appearance.borderRadius
    opacity: root.shown ? 1 : 0

    Behavior on opacity {
      NumberAnimation {
        duration: Appearance.animFast
      }
    }

    ColumnLayout {
      id: content
      anchors.centerIn: parent
      spacing: Widget.spacing * 2

      StyledText {
        Layout.alignment: Qt.AlignHCenter
        text: root.screen?.name ?? ""
        textSize: root.asking ? Appearance.fontSize : Appearance.fontSize * 3
        font.bold: true
        opacity: root.asking ? 0.6 : 1
      }

      StyledText {
        visible: !root.asking
        Layout.alignment: Qt.AlignHCenter
        text: String(root.screen?.model ?? "").trim()
        opacity: 0.7
      }

      StyledText {
        visible: root.asking
        Layout.alignment: Qt.AlignHCenter
        text: I18n.tr("Keep this display layout?")
        textSize: Appearance.fontSize + 4
        font.bold: true
      }

      StyledText {
        visible: root.asking
        Layout.alignment: Qt.AlignHCenter
        text: I18n.tr("Going back in {0} s", MonitorManager.secondsLeft)
        opacity: 0.7
      }

      RowLayout {
        visible: root.asking
        Layout.alignment: Qt.AlignHCenter
        spacing: Widget.spacing * 2

        StyledTextButton {
          text: I18n.tr("Revert")
          iconText: "undo"
          implicitHeight: Widget.height
          onClicked: MonitorManager.revert()
        }

        StyledTextButton {
          text: I18n.tr("Keep")
          iconText: "check"
          implicitHeight: Widget.height
          backgroundColor: Theme.accent
          textColor: Theme.background
          onClicked: MonitorManager.keep()
        }
      }
    }
  }
}
