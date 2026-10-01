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

  Layout.fillWidth: true
  spacing: Widget.spacing

  RowLayout {
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

    StyledTextButton {
      Layout.fillWidth: true
      iconText: "layers"
      text: EdgeMenuManager.showingOthers ? I18n.tr("Hide other menus") : I18n.tr("Show other menus")
      textPadding: 6
      backgroundColor: EdgeMenuManager.showingOthers ? Theme.accent : Theme.backgroundHighlight
      textColor: EdgeMenuManager.showingOthers ? Theme.background : Theme.foreground
      onClicked: EdgeMenuManager.toggleShowingOthers()
    }
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

  OpenerButtons {
    saved: EdgeMenuManager.isSaved(root.menu)
    unsavedHint: I18n.tr("Save the menu to add a bar button or keybind for it.")
    onBarButtonRequested: barIndex => EdgeMenuManager.addBarButton(barIndex, "right")
    onKeybindRequested: EdgeMenuManager.addKeybind()
  }
}
