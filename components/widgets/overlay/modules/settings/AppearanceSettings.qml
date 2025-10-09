pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import qs.config
import qs.components.widgets.common

SchemaSection {
  title: "Appearance"
  Layout.leftMargin: Widget.padding
  Layout.rightMargin: Widget.padding

  SchemaTextField {
    label: "Theme Name"
    value: root.localConfig.Appearance?.theme || ""
    placeholderText: "default"
    onValueChanged: {
      if (!root.localConfig.Appearance)
        root.localConfig.Appearance = {};
      root.localConfig.Appearance.theme = value;
      root.markDirty();
    }
  }

  SchemaSwitch {
    label: "Dark Mode"
    checked: root.localConfig.Appearance?.darkMode || false
    onCheckedChanged: {
      if (!root.localConfig.Appearance)
        root.localConfig.Appearance = {};
      root.localConfig.Appearance.darkMode = checked;
      root.markDirty();
    }
  }

  SchemaSwitch {
    label: "Auto Theme Switch"
    checked: root.localConfig.Appearance?.autoThemeSwitch || false
    description: "Automatically switch between light/dark"
    onCheckedChanged: {
      if (!root.localConfig.Appearance)
        root.localConfig.Appearance = {};
      root.localConfig.Appearance.autoThemeSwitch = checked;
      root.markDirty();
    }
  }

  GridLayout {
    Layout.fillWidth: true
    columns: 1
    columnSpacing: Widget.spacing
    rowSpacing: Widget.spacing

    SchemaSpinBox {
      label: "Border Radius"
      value: root.localConfig.Appearance?.borderRadius || 8
      minimum: 0
      maximum: 50
      description: "Roundness of corners (px)"
      onValueChanged: {
        if (!root.localConfig.Appearance)
          root.localConfig.Appearance = {};
        root.localConfig.Appearance.borderRadius = value;
        root.markDirty();
      }
    }

    SchemaSpinBox {
      label: "Border Width"
      value: root.localConfig.Appearance?.borderWidth || 1
      minimum: 0
      maximum: 10
      description: "Thickness of borders (px)"
      onValueChanged: {
        if (!root.localConfig.Appearance)
          root.localConfig.Appearance = {};
        root.localConfig.Appearance.borderWidth = value;
        root.markDirty();
      }
    }

    SchemaSpinBox {
      label: "Screen Margin"
      value: root.localConfig.Appearance?.screenMargin || 0
      minimum: 0
      maximum: 100
      description: "Space around screen edges (px)"
      onValueChanged: {
        if (!root.localConfig.Appearance)
          root.localConfig.Appearance = {};
        root.localConfig.Appearance.screenMargin = value;
        root.markDirty();
      }
    }
  }

  SchemaTextField {
    label: "Font Family"
    value: root.localConfig.Appearance?.fontFamily || "Inter"
    placeholderText: "Font name"
    onValueChanged: {
      if (!root.localConfig.Appearance)
        root.localConfig.Appearance = {};
      root.localConfig.Appearance.fontFamily = value;
      root.markDirty();
    }
  }

  SchemaSpinBox {
    label: "Font Size"
    value: root.localConfig.Appearance?.fontSize || 12
    minimum: 8
    maximum: 24
    description: "Base font size (px)"
    onValueChanged: {
      if (!root.localConfig.Appearance)
        root.localConfig.Appearance = {};
      root.localConfig.Appearance.fontSize = value;
      root.markDirty();
    }
  }
}
