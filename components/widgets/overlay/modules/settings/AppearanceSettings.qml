pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import qs.config
import qs.components.widgets.common

SchemaSection {
  id: appearanceSection
  title: "Appearance"

  required property var localConfig
  Layout.leftMargin: Widget.padding
  Layout.rightMargin: Widget.padding

  SchemaTextField {
    label: "Theme Name"
    value: localConfig.Appearance?.theme || ""
    placeholderText: "default"
    onValueChanged: {
      if (!localConfig.Appearance)
        localConfig.Appearance = {};
      localConfig.Appearance.theme = value;
      markDirty();
    }
  }

  SchemaSwitch {
    label: "Dark Mode"
    checked: appearanceSection.localConfig.Appearance?.darkMode || false
    onCheckedChanged: {
      if (!appearanceSection.localConfig.Appearance)
        appearanceSection.localConfig.Appearance = {};
      appearanceSection.localConfig.Appearance.darkMode = checked;
      markDirty();
    }
  }

  SchemaSwitch {
    label: "Auto Theme Switch"
    checked: appearanceSection.localConfig.Appearance?.autoThemeSwitch || false
    description: "Automatically switch between light/dark"
    onCheckedChanged: {
      if (!localConfig.Appearance)
        localConfig.Appearance = {};
      localConfig.Appearance.autoThemeSwitch = checked;
      markDirty();
    }
  }

  GridLayout {
    Layout.fillWidth: true
    columns: 1
    columnSpacing: Widget.spacing
    rowSpacing: Widget.spacing

    SchemaSpinBox {
      label: "Border Radius"
      value: localConfig.Appearance?.borderRadius || 8
      minimum: 0
      maximum: 50
      description: "Roundness of corners (px)"
      onValueChanged: {
        if (!localConfig.Appearance)
          localConfig.Appearance = {};
        localConfig.Appearance.borderRadius = value;
        markDirty();
      }
    }

    SchemaSpinBox {
      label: "Border Width"
      value: localConfig.Appearance?.borderWidth || 1
      minimum: 0
      maximum: 10
      description: "Thickness of borders (px)"
      onValueChanged: {
        if (!localConfig.Appearance)
          localConfig.Appearance = {};
        localConfig.Appearance.borderWidth = value;
        markDirty();
      }
    }

    SchemaSpinBox {
      label: "Screen Margin"
      value: localConfig.Appearance?.screenMargin || 0
      minimum: 0
      maximum: 100
      description: "Space around screen edges (px)"
      onValueChanged: {
        if (!localConfig.Appearance)
          localConfig.Appearance = {};
        localConfig.Appearance.screenMargin = value;
        markDirty();
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
      markDirty();
    }
  }

  SchemaSpinBox {
    label: "Font Size"
    value: localConfig.Appearance?.fontSize || 12
    minimum: 8
    maximum: 24
    description: "Base font size (px)"
    onValueChanged: {
      if (!localConfig.Appearance)
        localConfig.Appearance = {};
      localConfig.Appearance.fontSize = value;
      markDirty();
    }
  }
  SchemaSwitch {
    label: "Enable Animations"
    checked: root.localConfig.Widget?.animations !== undefined ? root.localConfig.Widget.animations : true
    onCheckedChanged: {
      if (!root.localConfig.Widget)
        root.localConfig.Widget = {};
      root.localConfig.Widget.animations = checked;
      root.markDirty();
    }
  }
  SchemaSpinBox {
    label: "Animation Duration"
    value: root.localConfig.Widget?.animationDuration || 200
    minimum: 0
    maximum: 1000
    visible: root.localConfig.Widget?.animations !== false
    description: "Duration in milliseconds"
    onValueChanged: {
      if (!root.localConfig.Widget)
        root.localConfig.Widget = {};
      root.localConfig.Widget.animationDuration = value;
      root.markDirty();
    }
  }
  SchemaSpinBox {
    label: "Container Width"
    value: root.localConfig.Widget?.containerWidth || 200
    minimum: 100
    maximum: 1000
    onValueChanged: {
      if (!root.localConfig.Widget)
        root.localConfig.Widget = {};
      root.localConfig.Widget.containerWidth = value;
      root.markDirty();
    }
  }
  SchemaSwitch {
    label: "Workspace Popout Icons"
    checked: root.localConfig.Widget?.workspacePopoutIcons || false
    description: "Show icons outside workspace container"
    onCheckedChanged: {
      if (!root.localConfig.Widget)
        root.localConfig.Widget = {};
      root.localConfig.Widget.workspacePopoutIcons = checked;
      root.markDirty();
    }
  }
}
