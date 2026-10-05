pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import qs.config
import qs.services
import qs.components.reusable

// One event in a list: its calendar's color, the title, and when (on
// `dayKey`) and where. A click opens it (unless not `clickable`).
Rectangle {
  id: root

  required property var event
  property string dayKey: ""
  // A second line for the time and place; without, the time leads the title
  property bool twoLines: true
  property bool clickable: true

  signal clicked

  readonly property string when: root.event ? CalendarManager.timeText(root.event, root.dayKey) : ""

  Layout.fillWidth: true
  implicitHeight: content.implicitHeight + Widget.spacing
  radius: Widget.radius
  color: area.containsMouse && root.clickable ? Qt.alpha(Theme.backgroundHighlight, 0.7) : Qt.alpha(Theme.backgroundHighlight, 0)

  Behavior on color {
    ColorAnimation {
      duration: Appearance.animFast
    }
  }

  RowLayout {
    id: content
    anchors.fill: parent
    anchors.leftMargin: Widget.spacing / 2
    anchors.rightMargin: Widget.spacing / 2
    spacing: Widget.spacing

    Rectangle {
      Layout.preferredWidth: 4
      Layout.fillHeight: true
      Layout.topMargin: Widget.spacing / 2
      Layout.bottomMargin: Widget.spacing / 2
      radius: 2
      color: CalendarConfig.colors[root.event?.calendar] ?? Theme.accent
    }

    ColumnLayout {
      Layout.fillWidth: true
      Layout.topMargin: Widget.spacing / 2
      Layout.bottomMargin: Widget.spacing / 2
      spacing: 0

      RowLayout {
        Layout.fillWidth: true
        spacing: Widget.spacing / 2

        StyledText {
          visible: !root.twoLines
          text: root.when
          textColor: Theme.foregroundAlt
          textSize: Appearance.fontSize - 1
        }
        StyledText {
          Layout.fillWidth: true
          text: root.event?.title || I18n.tr("(No title)")
          textFormat: Text.PlainText
          elide: Text.ElideRight
        }
        StyledIcon {
          visible: root.event?.recurring ?? false
          text: "repeat"
          textSize: Appearance.fontSize - 2
          textColor: Theme.foregroundAlt
        }
      }
      StyledText {
        visible: root.twoLines
        Layout.fillWidth: true
        text: root.event?.location ? I18n.tr("{0} · {1}", root.when, root.event.location) : root.when
        textFormat: Text.PlainText
        textColor: Theme.foregroundAlt
        textSize: Appearance.fontSize - 2
        elide: Text.ElideRight
      }
    }
  }

  MouseArea {
    id: area
    anchors.fill: parent
    enabled: root.clickable
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    onClicked: root.clicked()
  }
}
