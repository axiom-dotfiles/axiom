pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import qs.config
import qs.services
import qs.components.reusable

// Where a message is written: attached images above the text, attach
// buttons, and send (stop while a reply streams). Chat.sendKey picks
// Enter or Ctrl+Enter to send.
ColumnLayout {
  id: root

  readonly property alias input: area.input
  readonly property bool ctrlEnter: ChatConfig.sendKey === "ctrlEnter"

  function focusInput() {
    area.input.forceActiveFocus();
  }

  function _send() {
    if (ChatManager.busy)
      return;
    if (ChatManager.send(area.text))
      area.text = "";
  }

  spacing: Widget.spacing / 2

  StyledContainer {
    Layout.fillWidth: true
    implicitHeight: box.implicitHeight + Widget.spacing * 2
    backgroundColor: Theme.backgroundAlt
    borderColor: area.input.activeFocus ? Theme.accent : Theme.border
    borderWidth: 1
    borderRadius: Appearance.borderRadius + 2

    Behavior on borderColor {
      ColorAnimation {
        duration: Appearance.animNormal
      }
    }

    ColumnLayout {
      id: box
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.verticalCenter: parent.verticalCenter
      anchors.leftMargin: Widget.spacing
      anchors.rightMargin: Widget.spacing
      spacing: Widget.spacing / 2

      Flow {
        visible: ChatManager.attachments.length > 0 || ChatManager.attaching
        Layout.fillWidth: true
        Layout.leftMargin: 4
        Layout.topMargin: 4
        spacing: Widget.spacing / 2

        Repeater {
          model: ChatManager.attachments.length
          delegate: AttachmentChip {
            required property int index
            attachment: ChatManager.attachments[index]
            removable: true
            onRemoved: ChatManager.detach(index)
          }
        }

        Rectangle {
          visible: ChatManager.attaching
          width: 56
          height: 56
          radius: Appearance.borderRadius / 2
          color: Theme.backgroundHighlight

          StyledIcon {
            anchors.centerIn: parent
            text: "hourglass_empty"
            textColor: Theme.foregroundAlt
          }
        }
      }

      RowLayout {
        Layout.fillWidth: true
        spacing: 2

        StyledIconButton {
          Layout.fillWidth: false
          Layout.fillHeight: false
          Layout.alignment: Qt.AlignBottom
          Layout.bottomMargin: 5
          Layout.preferredWidth: 30
          Layout.preferredHeight: 30
          enabled: !ChatManager.attaching
          iconText: "content_paste"
          iconColor: Theme.foregroundAlt
          tooltipText: I18n.tr("Paste image")
          onClicked: ChatManager.attachClipboard()
        }

        StyledIconButton {
          Layout.fillWidth: false
          Layout.fillHeight: false
          Layout.alignment: Qt.AlignBottom
          Layout.bottomMargin: 5
          Layout.preferredWidth: 30
          Layout.preferredHeight: 30
          enabled: !ChatManager.attaching
          iconText: "screenshot_region"
          iconColor: Theme.foregroundAlt
          tooltipText: I18n.tr("Screenshot a region")
          onClicked: ChatManager.attachScreenshot()
        }

        StyledTextArea {
          id: area
          Layout.fillWidth: true
          Layout.maximumHeight: Appearance.fontSize * 12
          expandable: true
          newlineOnEnter: root.ctrlEnter
          backgroundColor: "transparent"
          borderColor: "transparent"
          borderWidth: 0
          placeholderText: I18n.tr("Message {0}…", ChatManager.preset.name)
          onAccepted: root._send()
        }

        Rectangle {
          id: sendButton
          readonly property bool canSend: ChatManager.busy || area.text.trim() !== "" || ChatManager.attachments.length > 0
          Layout.alignment: Qt.AlignBottom
          Layout.bottomMargin: 5
          implicitWidth: 30
          implicitHeight: 30
          radius: 15
          color: ChatManager.busy ? Theme.backgroundHighlight : canSend ? Theme.accent : Theme.backgroundHighlight
          opacity: canSend ? 1 : 0.5

          Behavior on color {
            ColorAnimation {
              duration: Appearance.animNormal
            }
          }

          StyledIcon {
            anchors.centerIn: parent
            text: ChatManager.busy ? "stop" : "arrow_upward"
            fill: 1
            textColor: ChatManager.busy ? Theme.foreground : sendButton.canSend ? Theme.background : Theme.foregroundAlt
            textSize: Appearance.fontSize + 2
          }

          TapHandler {
            onTapped: ChatManager.busy ? ChatManager.stop() : root._send()
          }
          HoverHandler {
            cursorShape: sendButton.canSend ? Qt.PointingHandCursor : Qt.ArrowCursor
          }
        }
      }
    }
  }

  // A problem, else the keys
  RowLayout {
    Layout.fillWidth: true
    Layout.leftMargin: 4
    spacing: Widget.spacing

    StyledText {
      visible: ChatManager.notice !== ""
      Layout.fillWidth: true
      text: ChatManager.notice
      textColor: Theme.warning
      textSize: Appearance.fontSize - 3
      elide: Text.ElideRight
    }

    KeyHint {
      visible: ChatManager.notice === ""
      key: root.ctrlEnter ? "Ctrl ↵" : "↵"
      label: I18n.tr("send")
    }
    KeyHint {
      visible: ChatManager.notice === ""
      key: root.ctrlEnter ? "↵" : "⇧ ↵"
      label: I18n.tr("new line")
    }
    Item {
      visible: ChatManager.notice === ""
      Layout.fillWidth: true
    }
  }
}
