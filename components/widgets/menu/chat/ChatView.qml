// components/widgets/menu/chat/ChatView.qml
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls

import qs.services
import qs.config
import qs.components.widgets.menu.chat

Rectangle {
  // This is the main container you asked for.
  // Height should be managed by its parent container (infinitely growing)
  // Width will fill its parent.
  id: chatView
  
  width: 400 // Default for standalone viewing, parent will override
  height: 600 // Default for standalone viewing, parent will override
  color: Theme.background

  readonly property alias wantsKeyboardFocus: chatInputBar.wantsKeyboardFocus

  ColumnLayout {
    anchors.fill: parent
    anchors.margins: 10
    spacing: 10

    ScrollView {
      id: scrollView
      Layout.fillWidth: true
      Layout.fillHeight: true
      clip: true
      ScrollBar.vertical.policy: ScrollBar.AlwaysOn

      ListView {
        id: listView
        width: scrollView.width
        model: Chat.chatModel
        delegate: ChatMessage {
          width: listView.width
        }
        spacing: 20
        
        // This makes the view scroll to the newest message
        onContentHeightChanged: {
            if (height < contentHeight) {
                scrollView.flickableItem.contentY = contentHeight - height;
            }
        }
      }
    }

    ChatInput {
      id: chatInputBar
      Layout.fillWidth: true
    }
  }
}
