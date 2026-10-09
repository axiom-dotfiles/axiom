pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import qs.config
import qs.components.methods
import qs.components.reusable

// One action: its label on the left, its key combos on the right,
// alternatives separated by a slash
RowLayout {
  id: root

  // { label, combos: [{ mods: ["SUPER"], keys: ["H", "←"] }] } (KeybindManager)
  required property var bind

  Layout.fillWidth: true
  spacing: Widget.spacing * 2

  StyledText {
    text: root.bind.label || I18n.tr("No description")
    opacity: root.bind.label ? 1 : 0.5
    elide: Text.ElideRight
    Layout.fillWidth: true
  }

  Repeater {
    model: root.bind.combos

    delegate: RowLayout {
      id: combo
      required property var modelData
      required property int index
      spacing: Widget.spacing / 2

      StyledText {
        visible: combo.index > 0
        text: "/"
        opacity: 0.4
        Layout.rightMargin: Widget.spacing / 2
      }

      Repeater {
        model: combo.modelData.mods

        delegate: KeyCap {
          required property string modelData
          text: KeyNames.modifierLabel(modelData)
        }
      }

      Repeater {
        model: combo.modelData.keys

        delegate: KeyCap {
          required property string modelData
          text: modelData
        }
      }
    }
  }
}
