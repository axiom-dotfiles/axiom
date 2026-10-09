pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import qs.config
import qs.components.reusable

// One section of keybinds as a card: its title, then a row per action
StyledContainer {
  id: root

  // A KeybindManager section, binds possibly filtered by a search
  required property var section

  Layout.fillWidth: true
  implicitHeight: column.implicitHeight + Widget.padding * 2

  ColumnLayout {
    id: column
    anchors.top: parent.top
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.margins: Widget.padding
    spacing: Widget.spacing

    SectionHeading {
      title: root.section.undescribed ? I18n.tr("Undescribed") : (root.section.title || I18n.tr("Other"))
      description: root.section.undescribed ? I18n.tr("A bind's description sets its label, and a \"Section: Label\" prefix picks its section.") : ""
      Layout.bottomMargin: Widget.spacing / 2
    }

    Repeater {
      model: root.section.binds

      delegate: KeybindRow {
        required property var modelData
        bind: modelData
      }
    }
  }
}
