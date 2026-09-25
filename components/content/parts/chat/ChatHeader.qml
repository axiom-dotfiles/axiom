import QtQuick
import QtQuick.Layouts
import qs.config
import qs.services
import qs.components.reusable

// The chat's top row: the conversation list toggle, the title, the
// preset/model chip and a new-chat button
RowLayout {
  id: root

  // The conversation list is docked beside the chat (no toggle needed)
  property bool listDocked: false
  property bool listOpen: false
  property bool pickerOpen: false

  signal toggleList
  signal togglePicker

  spacing: Widget.spacing / 2

  StyledIconButton {
    visible: !root.listDocked
    Layout.fillWidth: false
    Layout.fillHeight: false
    Layout.preferredWidth: 30
    Layout.preferredHeight: 30
    iconText: "history"
    iconColor: root.listOpen ? Theme.accent : Theme.foreground
    tooltipText: I18n.tr("Conversations")
    onClicked: root.toggleList()
  }

  StyledText {
    Layout.fillWidth: true
    Layout.leftMargin: root.listDocked ? Widget.spacing / 2 : 0
    text: ChatManager.conversation.title || I18n.tr("New conversation")
    font.bold: true
    elide: Text.ElideRight
  }

  // Preset and model
  Rectangle {
    Layout.maximumWidth: 220
    implicitWidth: chip.implicitWidth + Widget.padding * 1.5
    implicitHeight: 26
    radius: height / 2
    color: root.pickerOpen || chipHover.hovered ? Theme.backgroundHighlight : Theme.backgroundAlt
    border.color: root.pickerOpen ? Theme.accent : Theme.border
    border.width: 1

    Behavior on color {
      ColorAnimation {
        duration: Appearance.animFast
      }
    }

    RowLayout {
      id: chip
      anchors.fill: parent
      anchors.leftMargin: Widget.padding * 0.75
      anchors.rightMargin: Widget.padding * 0.5
      spacing: 4

      StyledIcon {
        text: ChatManager.preset.icon || "chat"
        textColor: Theme.accent
        textSize: Appearance.fontSize - 1
      }
      StyledText {
        Layout.fillWidth: true
        text: ChatManager.model || I18n.tr("No model")
        textSize: Appearance.fontSize - 2
        elide: Text.ElideMiddle
      }
      StyledIcon {
        text: "expand_more"
        textColor: Theme.foregroundAlt
        textSize: Appearance.fontSize - 1
      }
    }

    HoverHandler {
      id: chipHover
      cursorShape: Qt.PointingHandCursor
    }
    TapHandler {
      onTapped: root.togglePicker()
    }
  }

  StyledIconButton {
    Layout.fillWidth: false
    Layout.fillHeight: false
    Layout.preferredWidth: 30
    Layout.preferredHeight: 30
    iconText: "edit_square"
    tooltipText: I18n.tr("New conversation")
    onClicked: ChatManager.newConversation(ChatManager.preset.name)
  }
}
