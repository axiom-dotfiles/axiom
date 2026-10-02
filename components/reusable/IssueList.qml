pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import qs.config

// Problems found in an editor's draft, one per line: an icon and the
// text, red for errors, amber for warnings and accent for info. Modelled by count, so a
// fresh `issues` array rebinds the lines instead of rebuilding them.
ColumnLayout {
  id: root

  // [{ level: "error" | "warning" | "info", text }]
  property var issues: []
  property real textSize: Appearance.fontSize

  Layout.fillWidth: true
  spacing: Widget.spacing / 2
  visible: root.issues.length > 0

  Repeater {
    model: root.issues.length

    delegate: RowLayout {
      id: issue
      required property int index
      readonly property var entry: root.issues[issue.index] ?? {
        "level": "warning",
        "text": ""
      }
      readonly property color tone: entry.level === "error" ? Theme.error : entry.level === "info" ? Theme.accent : Theme.warning
      Layout.fillWidth: true
      spacing: Widget.spacing / 2

      StyledIcon {
        Layout.alignment: Qt.AlignTop
        text: issue.entry.level === "error" ? "error" : issue.entry.level === "info" ? "info" : "warning"
        textColor: issue.tone
        textSize: root.textSize
      }

      StyledText {
        text: issue.entry.text
        textColor: issue.tone
        textSize: root.textSize
        wrapMode: Text.WordWrap
        Layout.fillWidth: true
      }
    }
  }
}
