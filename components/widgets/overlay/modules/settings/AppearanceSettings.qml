pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import qs.config
import qs.services
import qs.components.widgets.common

SchemaSection {
  id: root
  title: "Appearance"
  expanded: true

  required property var localConfig

  Layout.leftMargin: Widget.padding
  Layout.rightMargin: Widget.padding

  SchemaSwitch {
    label: "Auto Theme Switch"
    checked: root.localConfig.Appearance?.autoThemeSwitch || false
    description: "Automatically switch between light/dark"
    onToggled: value => {
      if (value === checked) return;
      root.localConfig.Appearance.autoThemeSwitch = value;
      SettingsMenu.markDirty();
      SettingsMenu.continueStaging();
    }
  }

  GridLayout {
    Layout.fillWidth: true
    columns: 1
    columnSpacing: Widget.spacing
    rowSpacing: Widget.spacing

    SchemaSpinBox {
      label: "Border Radius"
      description: "Roundness of corners (px)"
      currentConfigValue: localConfig.Appearance?.borderRadius || 0
      minimum: 0
      maximum: 50
      onValueChanged: {
        if (!localConfig.Appearance)
          localConfig.Appearance = {};
        localConfig.Appearance.borderRadius = value;
        SettingsMenu.continueStaging();
      }
      onDirtied: {
        SettingsMenu.markDirty();
      }
    }

    SchemaSpinBox {
      label: "Border Width"
      currentConfigValue: localConfig.Appearance?.borderWidth || 0
      minimum: 0
      maximum: 10
      description: "Thickness of borders (px)"
      onValueChanged: {
        if (!localConfig.Appearance)
          localConfig.Appearance = {};
        localConfig.Appearance.borderWidth = value;
        SettingsMenu.continueStaging();
      }
      onDirtied: {
        SettingsMenu.markDirty();
      }
    }

    SchemaSpinBox {
      label: "Screen Margin"
      currentConfigValue: localConfig.Appearance?.screenMargin || 0
      minimum: 0
      maximum: 100
      description: "Space around screen edges (px)"
      onValueChanged: {
        if (!localConfig.Appearance)
          localConfig.Appearance = {};
        localConfig.Appearance.screenMargin = value;
        SettingsMenu.continueStaging();
      }
      onIsDirtyChanged: {
        SettingsMenu.markDirty();
      }
    }
  }

  SchemaTextField {
    label: "Font Family"
    value: localConfig.Appearance?.fontFamily || "Inter"
    placeholderText: "Font name"
    onValueChanged: {
      if (!localConfig.Appearance)
        localConfig.Appearance = {};
      localConfig.Appearance.fontFamily = value;
      SettingsMenu.markDirty();
    }
  }

  SchemaSpinBox {
    label: "Font Size"
    currentConfigValue: localConfig.Appearance?.fontSize || 0
    minimum: 8
    maximum: 24
    description: "Base font size (px)"
    onValueChanged: {
      if (!localConfig.Appearance)
        localConfig.Appearance = {};
      localConfig.Appearance.fontSize = value;
      SettingsMenu.markDirty();
    }
  }
  SchemaSwitch {
    label: "Enable Animations"
    checked: root.localConfig.Widget?.animations !== undefined ? root.localConfig.Widget.animations : true
    onToggled: value => {
      if (value === checked) return;
      root.localConfig.Widget.animations = value;
      SettingsMenu.markDirty();
      SettingsMenu.continueStaging();
    }
  }
  SchemaSpinBox {
    label: "Animation Duration"
    currentConfigValue: root.localConfig.Widget?.animationDuration || 0
    minimum: 0
    maximum: 1000
    visible: root.localConfig.Widget?.animations !== false
    description: "Duration in milliseconds"
    onValueChanged: {
      root.localConfig.Widget.animationDuration = value;
      SettingsMenu.markDirty();
    }
  }
  SchemaSpinBox {
    label: "Container Width"
    currentConfigValue: root.localConfig.Widget?.containerWidth || 0
    minimum: 100
    maximum: 1000
    onValueChanged: {
      root.localConfig.Widget.containerWidth = value;
      SettingsMenu.continueStaging();
    }
    onIsDirtyChanged: {
      SettingsMenu.markDirty();
    }
  }
  SchemaSwitch {
    label: "Workspace Popout Icons"
    checked: root.localConfig.Appearance?.workspacePopoutIcons || false
    description: "Show icons outside workspace container"
    onToggled: value => {
      if (value === checked) return;
      root.localConfig.Appearance.workspacePopoutIcons = value;
      SettingsMenu.markDirty();
      SettingsMenu.continueStaging();
    }
  }
}
