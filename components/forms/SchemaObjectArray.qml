// SchemaObjectArray.qml
pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import qs.config
import qs.components.reusable

// i18n: keys from callers and the schema (titles, descriptions, type labels)
ColumnLayout {
  id: root
  required property string label
  required property var items
  property string description: ""
  property int maxItems: 99
  property var itemDelegate: null
  property var itemHeaderExtra: null
  // Optional component shown in the header, between the label and "+"
  property var headerExtra: null
  // Room kept clear at the header's right end (the settings page's reset
  // button sits there)
  property int headerInset: 0

  signal itemAdded
  signal itemRemoved(int index)
  signal itemMoved(int fromIndex, int toIndex)

  Layout.fillWidth: true
  spacing: Widget.spacing

  RowLayout {
    Layout.fillWidth: true
    Layout.rightMargin: root.headerInset
    spacing: Widget.spacing

    StyledText {
      text: I18n.tr(root.label)
      textSize: Appearance.fontSize + 1
      font.bold: true
      Layout.fillWidth: true
    }

    Loader {
      active: root.headerExtra !== null
      sourceComponent: root.headerExtra
      Layout.alignment: Qt.AlignVCenter
    }

    StyledRectButton {
      visible: root.items.length < root.maxItems
      Layout.preferredWidth: Widget.height
      Layout.preferredHeight: Widget.height
      Layout.fillWidth: false
      Layout.fillHeight: false
      iconText: "add"
      iconSize: Appearance.fontSize + 4
      hoverColor: Theme.accent

      onClicked: {
        root.itemAdded();
      }
    }
  }

  StyledText {
    visible: root.description !== ""
    text: I18n.tr(root.description)
    opacity: 0.7
    textSize: Appearance.fontSize - 2
    wrapMode: Text.WordWrap
    Layout.fillWidth: true
  }

  ColumnLayout {
    Layout.fillWidth: true
    spacing: Widget.spacing

    // Keyed by count, not by the array: editing an item updates its
    // delegate in place instead of rebuilding every row (which would take
    // focus away from a text field on each keystroke)
    Repeater {
      model: root.items.length

      delegate: StyledContainer {
        id: entry
        required property int index
        readonly property var modelData: root.items[index]

        Layout.fillWidth: true
        implicitHeight: itemContent.implicitHeight + (Widget.padding * 2)

        ColumnLayout {
          id: itemContent
          anchors.fill: parent
          anchors.margins: Widget.padding
          spacing: Widget.spacing

          RowLayout {
            Layout.fillWidth: true
            spacing: 4

            StyledText {
              text: "#" + (entry.index + 1)
              textColor: Theme.accent
              textSize: Appearance.fontSize - 1
              font.bold: true
            }

            Loader {
              sourceComponent: root.itemHeaderExtra
              onLoaded: {
                item.itemData = Qt.binding(() => entry.modelData);
                item.itemIndex = Qt.binding(() => entry.index);
              }
            }

            Item {
              Layout.fillWidth: true
            }

            SquareIconButton {
              visible: entry.index > 0
              size: 24
              iconText: "expand_less"
              iconSize: 16
              hoverColor: Theme.accent

              onClicked: {
                root.itemMoved(entry.index, entry.index - 1);
              }
            }

            SquareIconButton {
              visible: entry.index < root.items.length - 1
              size: 24
              iconText: "expand_more"
              iconSize: 16
              hoverColor: Theme.accent

              onClicked: {
                root.itemMoved(entry.index, entry.index + 1);
              }
            }

            SquareIconButton {
              size: 24
              iconText: "close"
              iconSize: 18
              hoverColor: Theme.error

              onClicked: {
                root.itemRemoved(entry.index);
              }
            }
          }

          StyledSeparator {
            Layout.fillWidth: true
            separatorHeight: 1
            separatorColor: Theme.border
            opacity: 0.3
          }

          Loader {
            Layout.fillWidth: true
            sourceComponent: root.itemDelegate
            onLoaded: {
              item.itemData = Qt.binding(() => entry.modelData);
              item.itemIndex = Qt.binding(() => entry.index);
            }
          }
        }
      }
    }
  }

  StyledContainer {
    visible: root.items.length === 0
    Layout.fillWidth: true
    Layout.preferredHeight: 80
    backgroundColor: Theme.background

    StyledText {
      anchors.centerIn: parent
      text: I18n.tr("No items - click + to add")
      opacity: 0.5
    }
  }
}
