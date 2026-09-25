pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.config
import qs.services
import qs.components.reusable

// The conversation's preset, then each provider's models, in one list
Rectangle {
  id: root

  signal picked

  // Presets, then per provider a header and its models
  readonly property var rows: {
    const out = [
      {
        header: I18n.tr("Presets")
      }
    ];
    ChatConfig.presets.forEach(preset => out.push({
        preset: preset
      }));
    ChatConfig.providers.forEach(provider => {
      out.push({
        header: provider.name,
        provider: provider
      });
      const models = provider.models ?? [];
      if (models.length === 0)
        out.push({
          empty: provider
        });
      models.forEach(model => out.push({
          provider: provider,
          model: model
        }));
    });
    return out;
  }

  implicitHeight: Math.min(listColumn.implicitHeight + Widget.spacing * 2, 420)
  color: Theme.background
  radius: Appearance.borderRadius
  border.color: Theme.border
  border.width: 1

  Flickable {
    id: flick
    anchors.fill: parent
    anchors.margins: Widget.spacing
    contentWidth: width
    contentHeight: listColumn.implicitHeight
    clip: true
    boundsBehavior: Flickable.StopAtBounds

    ScrollBar.vertical: ScrollBar {
      policy: ScrollBar.AsNeeded
      contentItem: Rectangle {
        implicitWidth: 4
        radius: 2
        color: Theme.accent
        opacity: 0.4
      }
    }

    ColumnLayout {
      id: listColumn
      width: flick.width
      spacing: 1

      Repeater {
        model: root.rows.length
        delegate: Loader {
          id: row
          required property int index
          readonly property var rowData: root.rows[index] ?? ({})
          Layout.fillWidth: true
          sourceComponent: rowData.header !== undefined ? headerRow : rowData.empty ? emptyRow : choiceRow

          Component {
            id: headerRow
            RowLayout {
              width: row.width
              spacing: Widget.spacing / 2

              StyledText {
                Layout.topMargin: row.index > 0 ? Widget.spacing : 0
                Layout.leftMargin: Widget.spacing / 2
                Layout.fillWidth: true
                text: row.rowData.header
                textColor: Theme.foregroundAlt
                textSize: Appearance.fontSize - 3
                font.bold: true
              }

              // Whether the provider has a key
              StyledIcon {
                readonly property string status: row.rowData.provider ? SecretsManager.status(row.rowData.provider) : "unneeded"
                visible: status === "none"
                Layout.topMargin: row.index > 0 ? Widget.spacing : 0
                Layout.rightMargin: Widget.spacing / 2
                text: "key_off"
                textColor: Theme.warning
                textSize: Appearance.fontSize - 2
              }
            }
          }

          Component {
            id: emptyRow
            StyledText {
              width: row.width
              leftPadding: Widget.spacing
              text: I18n.tr("No models: fetch them in Settings → Chat")
              textColor: Theme.foregroundInactive
              textSize: Appearance.fontSize - 3
              wrapMode: Text.WordWrap
            }
          }

          Component {
            id: choiceRow
            Rectangle {
              id: choice
              readonly property var preset: row.rowData.preset ?? null
              readonly property bool selected: preset ? preset.name === ChatManager.preset.name : row.rowData.provider.id === ChatManager.provider?.id && row.rowData.model === ChatManager.model
              width: row.width
              implicitHeight: Widget.height - 4
              radius: Appearance.borderRadius / 2
              color: choiceHover.hovered ? Theme.backgroundHighlight : "transparent"

              HoverHandler {
                id: choiceHover
                cursorShape: Qt.PointingHandCursor
              }
              TapHandler {
                onTapped: {
                  if (choice.preset)
                    ChatManager.setPreset(choice.preset.name);
                  else
                    ChatManager.setModel(row.rowData.provider.id, row.rowData.model);
                  root.picked();
                }
              }

              RowLayout {
                anchors.fill: parent
                anchors.leftMargin: Widget.spacing
                anchors.rightMargin: Widget.spacing
                spacing: Widget.spacing

                StyledIcon {
                  visible: choice.preset !== null
                  text: choice.preset?.icon || "chat"
                  textColor: choice.selected ? Theme.accent : Theme.foregroundAlt
                  textSize: Appearance.fontSize
                }
                StyledText {
                  Layout.fillWidth: true
                  text: choice.preset ? choice.preset.name : row.rowData.model
                  textColor: choice.selected ? Theme.accent : Theme.foreground
                  textSize: Appearance.fontSize - 1
                  elide: Text.ElideRight
                }
                StyledIcon {
                  visible: choice.selected
                  text: "check"
                  textColor: Theme.accent
                  textSize: Appearance.fontSize
                }
              }
            }
          }
        }
      }
    }
  }
}
