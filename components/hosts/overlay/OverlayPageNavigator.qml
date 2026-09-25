pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.config
import qs.components.reusable

// Fixed page navigator for the overlay's pages: arrows at the ends and a tab
// per page (icon and name), the current one under a sliding accent pill.
// When every name doesn't fit `maxWidth`, the other tabs drop to their
// icons (named in a tooltip). Scrolling over it steps through the pages.
// Kept as its own item, anchored directly to the overlay's screen edge,
// so it doesn't move when the current page's content height changes.
Rectangle {
  id: root

  required property int currentIndex
  // [{ icon, label }], one per page (OverlayPages.pages)
  required property var pages
  // The widest it may get; 0 for no limit
  property real maxWidth: 0

  signal previous
  signal next
  signal select(int index)

  readonly property real inset: 6
  readonly property real controlHeight: root.height - root.inset * 2
  readonly property real innerRadius: Math.max(0, Appearance.borderRadius - root.inset / 2)
  readonly property real tabPadding: Widget.padding * 1.5
  readonly property real iconSize: Appearance.fontSize * 1.4
  readonly property real labelSpacing: Widget.spacing / 2
  // Everything but the tabs: arrows, the gaps beside them and the insets
  readonly property real chrome: root.controlHeight * 2 + row.spacing * 2 + root.inset * 2
  // Only the current tab keeps its name when all of them don't fit
  readonly property bool compact: root.maxWidth > 0 && root.chrome + measureRow.implicitWidth > root.maxWidth
  readonly property color onAccent: Theme.background

  width: row.implicitWidth + root.inset * 2
  height: Math.round(Widget.height * 1.5)
  radius: Appearance.borderRadius
  color: Theme.backgroundAlt
  border.color: Theme.foreground
  border.width: Appearance.borderWidth

  WheelHandler {
    acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
    property real _accumulated: 0
    onWheel: event => {
      _accumulated += event.angleDelta.y !== 0 ? event.angleDelta.y : event.angleDelta.x;
      if (Math.abs(_accumulated) < 120)
        return;
      if (_accumulated < 0)
        root.next();
      else
        root.previous();
      _accumulated = 0;
    }
  }

  // Every tab with its name, never shown: how wide the full row would be
  Row {
    id: measureRow
    visible: false
    Repeater {
      model: root.pages
      Item {
        required property var modelData
        implicitWidth: root.tabPadding * 2 + root.iconSize + root.labelSpacing + measureLabel.implicitWidth
        StyledText {
          id: measureLabel
          text: parent.modelData.label
        }
      }
    }
  }

  component ArrowButton: Rectangle {
    id: arrow
    property string icon
    signal clicked

    Layout.preferredWidth: root.controlHeight
    Layout.preferredHeight: root.controlHeight
    radius: root.innerRadius
    color: arrowArea.containsMouse ? Theme.backgroundHighlight : "transparent"

    StyledIcon {
      anchors.centerIn: parent
      text: arrow.icon
      textSize: root.iconSize * 1.2
      color: Theme.foreground
    }

    MouseArea {
      id: arrowArea
      anchors.fill: parent
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      onClicked: arrow.clicked()
    }

    Behavior on color {
      ColorAnimation {
        duration: Appearance.animFast
      }
    }
  }

  RowLayout {
    id: row
    anchors.centerIn: parent
    spacing: Widget.spacing / 2

    ArrowButton {
      icon: "chevron_left"
      onClicked: root.previous()
    }

    Item {
      Layout.preferredWidth: tabRow.implicitWidth
      Layout.preferredHeight: root.controlHeight

      // itemAt() isn't a notifying read: `count` re-evaluates it once the
      // tabs exist
      readonly property Item currentTab: tabs.count > root.currentIndex ? tabs.itemAt(root.currentIndex) : null

      Rectangle {
        id: pill
        x: parent.currentTab?.x ?? 0
        width: parent.currentTab?.width ?? 0
        height: parent.height
        radius: root.innerRadius
        color: Theme.accent
        visible: parent.currentTab !== null

        Behavior on x {
          NumberAnimation {
            duration: Appearance.animNormal
            easing.type: Easing.OutCubic
          }
        }
        Behavior on width {
          NumberAnimation {
            duration: Appearance.animNormal
            easing.type: Easing.OutCubic
          }
        }
      }

      Row {
        id: tabRow
        height: parent.height

        Repeater {
          id: tabs
          model: root.pages

          Rectangle {
            id: tab
            required property int index
            required property var modelData
            readonly property bool isCurrent: index === root.currentIndex
            readonly property bool showLabel: tab.isCurrent || !root.compact
            readonly property color ink: tab.isCurrent ? root.onAccent : Theme.foreground

            width: root.tabPadding * 2 + content.implicitWidth
            height: parent.height
            radius: root.innerRadius
            color: !tab.isCurrent && tabArea.containsMouse ? Theme.backgroundHighlight : "transparent"

            Row {
              id: content
              anchors.centerIn: parent
              spacing: tab.showLabel ? root.labelSpacing : 0

              StyledIcon {
                anchors.verticalCenter: parent.verticalCenter
                text: tab.modelData.icon
                textSize: root.iconSize
                fill: tab.isCurrent ? 1 : 0
                color: tab.ink
              }

              StyledText {
                anchors.verticalCenter: parent.verticalCenter
                text: tab.modelData.label
                visible: tab.showLabel
                font.weight: tab.isCurrent ? Font.DemiBold : Font.Normal
                color: tab.ink
              }
            }

            MouseArea {
              id: tabArea
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: root.select(tab.index)
            }

            LazyLoader {
              active: !tab.showLabel && tabArea.containsMouse
              StyledToolTip {
                target: tab
                text: tab.modelData.label
                edges: Edges.Top
              }
            }

            Behavior on color {
              ColorAnimation {
                duration: Appearance.animFast
              }
            }
          }
        }
      }
    }

    ArrowButton {
      icon: "chevron_right"
      onClicked: root.next()
    }
  }
}
