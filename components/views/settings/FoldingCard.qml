pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import qs.config
import qs.components.reusable

// A settings card that folds: clicking its header (title, help text,
// chevron) emits `toggled`, and the body below animates shut while
// `collapsed`. Folded with `marked` set, it shows the unsaved-edits dot.
// The generated cards (SettingsGroupCard) and the list cards
// (EntryListCard) are built on it.
StyledContainer {
  id: root

  property string title
  // Shown only while unfolded
  property string description
  // A line above the title (the section, in search results)
  property string section
  property bool collapsed: false
  // False: the header doesn't fold it (search results)
  property bool foldable: true
  property bool marked: false
  // Beside the header, while unfolded (an Add button)
  property alias headerExtras: extras.data
  default property alias content: body.data

  signal toggled

  Layout.fillWidth: true
  implicitHeight: column.implicitHeight + Widget.padding * 2

  ColumnLayout {
    id: column
    anchors.top: parent.top
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.margins: Widget.padding
    spacing: Widget.spacing * 1.5

    RowLayout {
      Layout.fillWidth: true
      spacing: Widget.spacing

      Item {
        Layout.fillWidth: true
        Layout.alignment: Qt.AlignTop
        implicitHeight: header.implicitHeight

        MouseArea {
          id: headerArea
          anchors.fill: parent
          enabled: root.foldable
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: root.toggled()
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
              visible: root.section !== ""
              text: root.section
              opacity: 0.6
              textSize: Appearance.fontSize - 2
              Layout.fillWidth: true
            }

            SectionHeading {
              title: root.title
              description: root.collapsed ? "" : root.description
            }
          }

          UnsavedDot {
            visible: root.collapsed && root.marked
            Layout.alignment: Qt.AlignTop
            Layout.topMargin: Appearance.fontSize / 2
          }

          StyledIcon {
            visible: root.foldable
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

      RowLayout {
        id: extras
        visible: !root.collapsed && children.length > 0
        Layout.alignment: Qt.AlignTop
        spacing: Widget.spacing
      }
    }

    // The body, clipped while folding. `shown` animates only on a toggle,
    // not when the page is built
    Item {
      property real shown: root.collapsed ? 0 : 1
      Layout.fillWidth: true
      Layout.preferredHeight: body.implicitHeight * shown
      visible: shown > 0
      clip: shown < 1

      Behavior on shown {
        NumberAnimation {
          duration: Appearance.animNormal
          easing.type: Easing.OutCubic
        }
      }

      ColumnLayout {
        id: body
        anchors.left: parent.left
        anchors.right: parent.right
        spacing: Widget.spacing * 1.5
      }
    }
  }
}
