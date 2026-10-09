pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import qs.config
import qs.services
import qs.components.reusable

// The top of the Translucency card (its `x-intro`): a warning that it's
// experimental, and while the surfaces blur, the blur they get: Hyprland's
// one (HyprlandManager.blur, as in effect), set by the window look's blur
// part or the user's own config. With Hyprland's blur off nothing blurs,
// and it offers to set it.
ColumnLayout {
  id: root

  readonly property bool off: !HyprlandManager.blur.enabled

  spacing: Widget.spacing

  RowLayout {
    Layout.fillWidth: true
    spacing: Widget.spacing

    StyledIcon {
      text: "science"
      textColor: Theme.warning
    }

    StyledText {
      Layout.fillWidth: true
      wrapMode: Text.WordWrap
      textColor: Theme.warning
      text: I18n.tr("Transparency and blur are highly experimental: expect visual glitches and a performance cost.")
    }
  }

  RowLayout {
    Layout.fillWidth: true
    visible: Appearance.blur
    spacing: Widget.spacing

    StatusChip {
      text: root.off ? I18n.tr("Off") : I18n.tr("Blur")
      color: root.off ? Theme.error : Theme.success
    }

    StyledText {
      Layout.fillWidth: true
      wrapMode: Text.WordWrap
      textColor: root.off ? Theme.error : Theme.foreground
      text: {
        if (root.off)
          return I18n.tr("Hyprland's blur is off, so nothing blurs behind the surfaces.");
        const strength = I18n.tr("Hyprland's blur: size {0}, {1} passes.", HyprlandManager.blur.size, HyprlandManager.blur.passes);
        return strength + " " + (HyprlandConfig.look.blur ? I18n.tr("Set in Hyprland → Window look.") : I18n.tr("From your Hyprland config."));
      }
    }

    StyledTextButton {
      implicitHeight: Widget.height - 4
      text: root.off && !HyprlandConfig.look.blur ? I18n.tr("Set Hyprland's blur") : I18n.tr("Change")
      onClicked: {
        if (root.off && !HyprlandConfig.look.blur)
          SettingsManager.setValue(["Hyprland", "look", "blur"], true);
        SettingsManager.openSection("Hyprland");
        Qt.callLater(() => SettingsManager.jumpTo("Hyprland.look:Blur"));
      }
    }
  }
}
