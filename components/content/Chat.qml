pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import qs.config
import qs.services
import qs.components.content.base
import qs.components.content.parts
import qs.components.content.parts.chat

// The AI chat (ChatManager): an overlay module, and ready to be a bar
// popout (it's a Panel). In a wide slot the conversation list is docked on
// the left; otherwise it slides over the chat. Images can be dropped on it.
Panel {
  id: root

  readonly property bool listDocked: root.embedded && root.shape === "horizontal"
  property bool listOpen: false
  property bool pickerOpen: false

  implicitWidth: 440 + root.margins * 2
  wantsKeyboardFocus: true
  spacing: 0

  compactContent: Component {
    CompactFigure {
      icon: "smart_toy"
      label: ChatManager.conversation.title || I18n.tr("Chat")
    }
  }

  Item {
    Layout.fillWidth: true
    Layout.fillHeight: true
    Layout.preferredHeight: root.embedded ? -1 : 560

    RowLayout {
      anchors.fill: parent
      spacing: Widget.padding

      ConversationList {
        visible: root.listDocked
        Layout.fillHeight: true
        Layout.preferredWidth: Math.max(180, parent.width * 0.32)
        color: Theme.backgroundAlt
        border.width: 0
      }

      ColumnLayout {
        Layout.fillWidth: true
        Layout.fillHeight: true
        spacing: Widget.spacing

        ChatHeader {
          Layout.fillWidth: true
          listDocked: root.listDocked
          listOpen: root.listOpen
          pickerOpen: root.pickerOpen
          onToggleList: {
            root.pickerOpen = false;
            root.listOpen = !root.listOpen;
          }
          onTogglePicker: {
            root.listOpen = false;
            root.pickerOpen = !root.pickerOpen;
          }
        }

        Rectangle {
          Layout.fillWidth: true
          implicitHeight: 1
          color: Theme.border
          opacity: 0.6
        }

        ChatMessageList {
          Layout.fillWidth: true
          Layout.fillHeight: true
        }

        ChatComposer {
          id: composer
          Layout.fillWidth: true
        }
      }
    }

    // Anything open over the chat closes on a click beside it
    MouseArea {
      anchors.fill: parent
      visible: root.listOpen || root.pickerOpen
      onClicked: {
        root.listOpen = false;
        root.pickerOpen = false;
      }
    }

    ConversationList {
      visible: !root.listDocked && root.listOpen
      anchors.top: parent.top
      anchors.topMargin: 36
      anchors.left: parent.left
      anchors.bottom: parent.bottom
      width: Math.min(parent.width - Widget.padding * 2, 300)
      onPicked: root.listOpen = false
    }

    ModelPicker {
      visible: root.pickerOpen
      anchors.top: parent.top
      anchors.topMargin: 36
      anchors.right: parent.right
      width: Math.min(parent.width - Widget.padding * 2, 280)
      onPicked: root.pickerOpen = false
    }

    DropArea {
      id: drop
      anchors.fill: parent
      keys: ["text/uri-list"]
      onDropped: event => {
        for (const url of event.urls)
          ChatManager.attachFile(url);
      }

      Rectangle {
        visible: drop.containsDrag
        anchors.fill: parent
        radius: Appearance.borderRadius
        color: Qt.alpha(Theme.accent, 0.12)
        border.color: Theme.accent
        border.width: 2
      }
    }
  }
}
