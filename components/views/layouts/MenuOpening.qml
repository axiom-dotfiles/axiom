pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import qs.config
import qs.services
import qs.components.reusable

// The top of an edge menu's Opening group: try it on screen, what opens
// it besides hovering its edge, and buttons that add a bar button or a
// keybind for it
ColumnLayout {
  id: root

  required property var menu
  readonly property bool previewingThis: !!root.menu && EdgeMenuManager.previewing !== "" && EdgeMenuManager.previewing === root.menu.id
  readonly property var references: EdgeMenuManager.references(root.menu?.id ?? "")
  readonly property var bars: BarManager.localConfig ?? Bar.savedBars

  Layout.fillWidth: true
  spacing: Widget.spacing

  StyledTextButton {
    Layout.fillWidth: true
    enabled: EdgeMenuManager.canPreview(root.menu)
    opacity: enabled ? 1 : 0.5
    iconText: root.previewingThis ? "visibility_off" : "visibility"
    text: root.previewingThis ? I18n.tr("Hide from screen") : I18n.tr("Show on screen")
    textPadding: 6
    backgroundColor: root.previewingThis ? Theme.accent : Theme.backgroundHighlight
    textColor: root.previewingThis ? Theme.background : Theme.foreground
    onClicked: EdgeMenuManager.togglePreviewing()
  }

  StyledText {
    Layout.fillWidth: true
    wrapMode: Text.WordWrap
    text: EdgeMenuManager.canPreview(root.menu) ? I18n.tr("Holds the menu open on its screen while you edit it, showing unsaved changes.") : I18n.tr("Enable the menu to show it.")
    textSize: Appearance.fontSize - 2
    opacity: 0.7
  }

  StyledText {
    Layout.topMargin: Widget.spacing / 2
    text: I18n.tr("Also opened by")
  }

  Repeater {
    model: root.references.length

    RowLayout {
      id: reference
      required property int index
      readonly property var ref: root.references[reference.index] ?? ({})
      Layout.fillWidth: true
      spacing: Widget.spacing

      StyledIcon {
        text: reference.ref.kind === "bind" ? "keyboard" : "toolbar"
        textColor: Theme.accent
      }
      StyledText {
        Layout.fillWidth: true
        text: reference.ref.label ?? ""
        elide: Text.ElideRight
      }
    }
  }

  StyledText {
    visible: root.references.length === 0
    Layout.fillWidth: true
    wrapMode: Text.WordWrap
    text: root.menu?.openOnHover ? I18n.tr("Nothing else yet: it opens when the pointer rests on its edge.") : I18n.tr("Nothing yet: turn on Open on hover, or add a bar button or keybind.")
    textSize: Appearance.fontSize - 2
    textColor: root.menu?.openOnHover ? Theme.foreground : Theme.warning
    opacity: root.menu?.openOnHover ? 0.7 : 1
  }

  Flow {
    Layout.fillWidth: true
    spacing: Widget.spacing / 2

    Repeater {
      model: root.bars.length

      StyledTextButton {
        required property int index
        iconText: "add"
        text: I18n.tr("Button on {0}", BarManager.barLabel(index))
        textPadding: 6
        onClicked: EdgeMenuManager.addBarButton(index, "right")
      }
    }

    StyledTextButton {
      iconText: "keyboard"
      text: I18n.tr("Add a keybind")
      textPadding: 6
      onClicked: EdgeMenuManager.addKeybind()
    }
  }
}
