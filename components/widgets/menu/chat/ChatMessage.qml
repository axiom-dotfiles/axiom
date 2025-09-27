// components/widgets/menu/chat/ChatMessage.qml
import QtQuick
import QtQuick.Layouts

import qs.config
import qs.components.reusable

RowLayout {
  width: parent.width
  spacing: 10

  property string role: "user"
  property string content: "..."

  readonly property bool isUser: role === "user"

  StyledText {
    text: isUser ? "👤" : "🤖"
    textSize: Appearance.fontSizeLarge
    Layout.alignment: Qt.AlignTop
    Layout.topMargin: 4
  }

  ColumnLayout {
    Layout.fillWidth: true
    spacing: 4

    StyledText {
      text: isUser ? "You" : "Assistant"
      textColor: isUser ? Theme.userColor : Theme.robotColor
      textSize: Appearance.fontSizeLarge
      font.bold: true
    }

    StyledText {
      text: content
      wrapMode: Text.WordWrap
      width: parent.width
      font.pixelSize: Appearance.fontSize
      color: Theme.foreground
    }
  }
}
