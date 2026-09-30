pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import qs.config
import qs.components.reusable

// A radio menu's list of devices or networks (Wi-Fi, Bluetooth). In a
// popout it's a fixed `visibleRows` rows high, so rows coming and going, or
// the radio switching off, never resize the popout; in a card it fills the
// height. Off, a message takes the list's place. Rows are `delegate`s
// (DeviceRows, with `required property int index`), modelled by `count` so
// they survive the list being re-evaluated.
Item {
  id: root

  property bool embedded: false
  // Off: the message shows instead of the list
  property bool on: true
  property string offIcon: ""
  property string offMessage: ""
  property string emptyText: ""
  property int count: 0
  property Component delegate
  property int visibleRows: 5

  // One row's height (DeviceRow.rowHeight): its two lines, or a button
  readonly property real rowHeight: Math.max(titleMetrics.height + statusMetrics.height, 28) + Widget.spacing * 2
  readonly property real listHeight: rowHeight * visibleRows + list.spacing * (visibleRows - 1)

  // Fades the rows in, e.g. on a tab switch
  function fadeIn() {
    fade.restart();
  }

  Layout.fillWidth: true
  Layout.preferredHeight: root.embedded ? -1 : root.listHeight
  Layout.fillHeight: root.embedded

  FontMetrics {
    id: titleMetrics
    font.family: Appearance.fontFamily
    font.pixelSize: Appearance.fontSize - 1
  }
  FontMetrics {
    id: statusMetrics
    font.family: Appearance.fontFamily
    font.pixelSize: Appearance.fontSize - 3
  }

  EmptyState {
    visible: !root.on
    anchors.centerIn: parent
    maxWidth: parent.width
    icon: root.offIcon
    text: root.offMessage
  }

  StyledScrollView {
    id: scroll
    visible: root.on
    anchors.fill: parent
    contentPadding: 0
    showScrollBar: list.implicitHeight > scroll.height

    ColumnLayout {
      id: list
      width: scroll.availableWidth
      spacing: 2

      NumberAnimation on opacity {
        id: fade
        from: 0
        to: 1
        duration: Appearance.animNormal
      }

      Repeater {
        model: root.count
        delegate: root.delegate
      }

      StyledText {
        Layout.fillWidth: true
        Layout.preferredHeight: scroll.availableHeight
        visible: root.count === 0
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        wrapMode: Text.WordWrap
        text: root.emptyText
        textColor: Theme.foregroundAlt
      }
    }
  }
}
