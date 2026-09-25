import QtQuick
import QtQuick.Layouts
import qs.config
import qs.services
import qs.components.reusable

// A fenced code block in a reply: its language, a copy button and the code
// in a monospace font. `open` while its closing fence is still streaming in.
StyledContainer {
  id: root

  property string code: ""
  property string lang: ""
  property bool open: false

  property bool _copied: false

  implicitHeight: column.implicitHeight
  backgroundColor: Theme.backgroundAlt
  borderColor: Theme.border
  borderWidth: 1
  clip: true

  ColumnLayout {
    id: column
    anchors.left: parent.left
    anchors.right: parent.right
    spacing: 0

    RowLayout {
      Layout.fillWidth: true
      Layout.leftMargin: Widget.padding
      Layout.rightMargin: Widget.spacing / 2
      Layout.topMargin: 2
      spacing: Widget.spacing / 2

      StyledText {
        Layout.fillWidth: true
        text: root.lang || I18n.tr("code")
        textColor: Theme.foregroundAlt
        textSize: Appearance.fontSize - 3
        textFamily: "monospace"
        elide: Text.ElideRight
      }

      StyledIconButton {
        Layout.fillWidth: false
        Layout.fillHeight: false
        Layout.preferredWidth: 26
        Layout.preferredHeight: 26
        iconText: root._copied ? "check" : "content_copy"
        iconSize: Appearance.fontSize - 1
        iconColor: root._copied ? Theme.success : Theme.foregroundAlt
        tooltipText: I18n.tr("Copy")
        onClicked: {
          ChatManager.copy(root.code);
          root._copied = true;
          copiedTimer.restart();
        }
      }
    }

    Rectangle {
      Layout.fillWidth: true
      implicitHeight: 1
      color: Theme.border
      opacity: 0.6
    }

    TextEdit {
      id: codeText
      Layout.fillWidth: true
      Layout.margins: Widget.padding
      text: root.code
      readOnly: true
      selectByMouse: true
      wrapMode: TextEdit.WrapAnywhere
      textFormat: TextEdit.PlainText
      color: Theme.foreground
      selectionColor: Theme.accent
      selectedTextColor: Theme.background
      font.family: "monospace"
      font.pixelSize: Appearance.fontSize - 1

      HoverHandler {
        cursorShape: Qt.IBeamCursor
      }
    }
  }

  Timer {
    id: copiedTimer
    interval: 1500
    onTriggered: root._copied = false
  }
}
