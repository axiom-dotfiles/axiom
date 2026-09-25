pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import qs.config
import qs.services
import qs.components.reusable

// i18n: keys from the schema (titles, descriptions)
// One group of settings (a section's own fields, or one nested object) as
// a card: title, help text, then its rows. Clicking the header folds it
// (remembered by SettingsManager); search results are always unfolded.
StyledContainer {
  id: root

  // A SchemaLayout.groups() entry, rows possibly filtered by a search
  required property var group
  // Provides valueAt(path) and edited(path, value) (SettingsContent)
  required property var form
  // Searching: name the section too, since cards come from all over
  property bool showSection: false

  readonly property bool collapsed: !root.showSection && SettingsManager.isCollapsed(root.group.key)
  // Folded with unsaved edits inside: marked, so they aren't forgotten
  readonly property bool hasChanges: root.group.rows.some(row => SettingsManager.hasChangesUnder(row.path.join(".")))

  Layout.fillWidth: true
  implicitHeight: column.implicitHeight + Widget.padding * 2
  backgroundColor: Theme.backgroundAlt

  ColumnLayout {
    id: column
    anchors.top: parent.top
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.margins: Widget.padding
    spacing: Widget.spacing * 1.5

    // Header: section, title and help text, with the fold chevron
    Item {
      Layout.fillWidth: true
      implicitHeight: header.implicitHeight

      MouseArea {
        id: headerArea
        anchors.fill: parent
        enabled: !root.showSection
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: SettingsManager.setCollapsed(root.group.key, !root.collapsed)
      }

      RowLayout {
        id: header
        anchors.left: parent.left
        anchors.right: parent.right
        spacing: Widget.spacing

        ColumnLayout {
          Layout.fillWidth: true
          spacing: 2

          StyledText {
            visible: root.showSection && root.group.section !== root.group.title
            text: I18n.tr(root.group.section)
            opacity: 0.6
            textSize: Appearance.fontSize - 2
            Layout.fillWidth: true
          }

          StyledText {
            text: I18n.tr(root.group.title)
            textColor: Theme.accent
            textSize: Appearance.fontSize + 1
            font.bold: true
            Layout.fillWidth: true
          }

          StyledText {
            visible: !root.collapsed && root.group.description !== ""
            text: I18n.tr(root.group.description)
            opacity: 0.7
            textSize: Appearance.fontSize - 2
            wrapMode: Text.WordWrap
            Layout.fillWidth: true
          }
        }

        Rectangle {
          visible: root.collapsed && root.hasChanges
          implicitWidth: 8
          implicitHeight: 8
          radius: 4
          color: Theme.accent
          Layout.alignment: Qt.AlignTop
          Layout.topMargin: Appearance.fontSize / 2
        }

        StyledIcon {
          visible: !root.showSection
          text: "expand_more"
          textColor: headerArea.containsMouse ? Theme.accent : Theme.foregroundAlt
          textSize: Appearance.fontSize + 4
          rotation: root.collapsed ? -90 : 0
          Layout.alignment: Qt.AlignTop

          Behavior on rotation {
            NumberAnimation {
              duration: Appearance.animNormal
              easing.type: Easing.OutCubic
            }
          }
        }
      }
    }

    // The rows, clipped while folding. `shown` animates only on a toggle,
    // not when the page is built
    Item {
      id: body
      property real shown: root.collapsed ? 0 : 1
      Layout.fillWidth: true
      Layout.preferredHeight: rows.implicitHeight * shown
      visible: shown > 0
      clip: shown < 1

      Behavior on shown {
        NumberAnimation {
          duration: Appearance.animNormal
          easing.type: Easing.OutCubic
        }
      }

      ColumnLayout {
        id: rows
        anchors.left: parent.left
        anchors.right: parent.right
        spacing: Widget.spacing * 1.5

        Repeater {
          model: root.group.rows

          delegate: SettingsField {
            required property var modelData
            row: modelData
            form: root.form
          }
        }
      }
    }
  }
}
