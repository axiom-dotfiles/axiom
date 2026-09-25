pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import qs.config
import qs.services
import qs.components.reusable

// Saved conversations, newest first under Today / Yesterday / Earlier,
// with search, rename and delete
Rectangle {
  id: root

  signal picked

  // Over the chat (not docked beside it): casts a shadow
  property bool floating: true

  property string query: ""
  // The conversation being renamed ("" when none)
  property string renaming: ""

  readonly property var rows: {
    const wanted = root.query.trim().toLowerCase();
    const list = ChatManager.conversations.filter(c => wanted === "" || (c.title ?? "").toLowerCase().includes(wanted));
    const today = new Date();
    today.setHours(0, 0, 0, 0);
    const startOfToday = today.getTime();
    const startOfYesterday = startOfToday - 24 * 60 * 60 * 1000;
    const out = [];
    let group = "";
    list.forEach(c => {
      // I18n.tr("Today") I18n.tr("Yesterday") I18n.tr("Earlier")
      const name = c.updated >= startOfToday ? "Today" : c.updated >= startOfYesterday ? "Yesterday" : "Earlier";
      if (name !== group) {
        group = name;
        out.push({
          header: I18n.tr(name)
        });
      }
      out.push({
        conversation: c
      });
    });
    return out;
  }

  color: Theme.background
  radius: Appearance.borderRadius
  border.color: Theme.border
  border.width: 1

  // Floats over the chat, like a combo box's list
  layer.enabled: root.floating
  // Qt 6 MultiEffect: Qt5Compat DropShadow fails to build its shader here
  layer.effect: MultiEffect {
    shadowEnabled: true
    shadowColor: "#40000000"
    shadowBlur: 0.5
    shadowVerticalOffset: 2
  }

  ColumnLayout {
    anchors.fill: parent
    anchors.margins: Widget.spacing
    spacing: Widget.spacing

    StyledTextEntry {
      Layout.fillWidth: true
      Layout.preferredHeight: Widget.height
      placeholderText: I18n.tr("Search conversations")
      onTextChanged: root.query = text
    }

    StyledScrollView {
      id: scroll
      Layout.fillWidth: true
      Layout.fillHeight: true
      contentPadding: 0
      // A lane of its own for the scroll bar, so it never covers a row
      showScrollBar: listColumn.implicitHeight > scroll.height
      rightPadding: showScrollBar ? 12 : 0

      ColumnLayout {
        id: listColumn
        width: scroll.availableWidth
        spacing: 2

        Repeater {
          model: root.rows.length
          delegate: Loader {
            id: row
            required property int index
            readonly property var rowData: root.rows[index] ?? ({})
            Layout.fillWidth: true
            sourceComponent: rowData.header !== undefined ? headerRow : itemRow

            Component {
              id: headerRow
              StyledText {
                width: row.width
                topPadding: row.index > 0 ? Widget.spacing * 2 : Widget.spacing / 2
                bottomPadding: Widget.spacing / 2
                leftPadding: Widget.spacing
                text: row.rowData.header
                textColor: Theme.foregroundAlt
                textSize: Appearance.fontSize - 3
                font.bold: true
              }
            }

            Component {
              id: itemRow
              Rectangle {
                id: item
                readonly property var conversation: row.rowData.conversation
                readonly property bool current: conversation.id === ChatManager.conversation.id
                readonly property bool editing: root.renaming === conversation.id
                width: row.width
                implicitHeight: Math.max(Widget.height, itemRowLayout.implicitHeight + Widget.spacing)
                radius: Appearance.borderRadius / 2
                color: current ? Qt.alpha(Theme.accent, 0.16) : itemHover.hovered ? Theme.backgroundHighlight : "transparent"

                HoverHandler {
                  id: itemHover
                }
                TapHandler {
                  enabled: !item.editing
                  onTapped: {
                    ChatManager.open(item.conversation.id);
                    root.picked();
                  }
                }

                RowLayout {
                  id: itemRowLayout
                  anchors.fill: parent
                  anchors.leftMargin: Widget.spacing
                  anchors.rightMargin: 3
                  spacing: 0

                  StyledText {
                    visible: !item.editing
                    Layout.fillWidth: true
                    text: item.conversation.title || I18n.tr("Untitled")
                    textColor: item.current ? Theme.accent : Theme.foreground
                    textSize: Appearance.fontSize - 1
                    elide: Text.ElideRight
                  }

                  StyledTextEntry {
                    id: renameField
                    visible: item.editing
                    Layout.fillWidth: true
                    Layout.preferredHeight: Widget.height - 6
                    text: item.conversation.title ?? ""
                    onVisibleChanged: {
                      if (visible) {
                        input.forceActiveFocus();
                        input.selectAll();
                      }
                    }
                    onAccepted: {
                      ChatManager.rename(item.conversation.id, text);
                      root.renaming = "";
                    }
                    input.Keys.onEscapePressed: root.renaming = ""
                  }

                  ChatIconButton {
                    visible: itemHover.hovered && !item.editing
                    size: 24
                    iconText: "edit"
                    iconSize: Appearance.fontSize - 2
                    tooltipText: I18n.tr("Rename")
                    onClicked: root.renaming = item.conversation.id
                  }
                  ChatIconButton {
                    visible: itemHover.hovered && !item.editing
                    size: 24
                    iconText: "delete"
                    iconSize: Appearance.fontSize - 2
                    tooltipText: I18n.tr("Delete")
                    onClicked: ChatManager.remove(item.conversation.id)
                  }
                }
              }
            }
          }
        }

        StyledText {
          visible: root.rows.length === 0
          Layout.fillWidth: true
          Layout.topMargin: Widget.padding
          horizontalAlignment: Text.AlignHCenter
          wrapMode: Text.WordWrap
          text: ChatConfig.keepConversations === 0 ? I18n.tr("Conversations aren't saved (Settings → Chat).") : root.query !== "" ? I18n.tr("No matches") : I18n.tr("No conversations yet")
          textColor: Theme.foregroundAlt
          textSize: Appearance.fontSize - 2
        }
      }
    }
  }
}
