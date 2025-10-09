pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import qs.config
import qs.components.widgets.common

SchemaSection {
  title: "Theme Integrations"
  description: "Sync theme with external applications"
  Layout.leftMargin: Widget.padding
  Layout.rightMargin: Widget.padding

  SchemaSwitch {
    label: "GTK Integration"
    checked: root.localConfig.ThemeIntegrations?.gtk || false
    onCheckedChanged: {
      if (!root.localConfig.ThemeIntegrations)
        root.localConfig.ThemeIntegrations = {};
      root.localConfig.ThemeIntegrations.gtk = checked;
      root.markDirty();
    }
  }

  SchemaSwitch {
    label: "Neovim Integration"
    checked: root.localConfig.ThemeIntegrations?.nvim || false
    onCheckedChanged: {
      if (!root.localConfig.ThemeIntegrations)
        root.localConfig.ThemeIntegrations = {};
      root.localConfig.ThemeIntegrations.nvim = checked;
      root.markDirty();
    }
  }

  SchemaSwitch {
    label: "VS Code Integration"
    checked: root.localConfig.ThemeIntegrations?.vscode || false
    onCheckedChanged: {
      if (!root.localConfig.ThemeIntegrations)
        root.localConfig.ThemeIntegrations = {};
      root.localConfig.ThemeIntegrations.vscode = checked;
      root.markDirty();
    }
  }

  SchemaSwitch {
    label: "Alacritty Integration"
    checked: root.localConfig.ThemeIntegrations?.alacritty || false
    onCheckedChanged: {
      if (!root.localConfig.ThemeIntegrations)
        root.localConfig.ThemeIntegrations = {};
      root.localConfig.ThemeIntegrations.alacritty = checked;
      root.markDirty();
    }
  }

  SchemaSwitch {
    label: "Kitty Integration"
    checked: root.localConfig.ThemeIntegrations?.kitty || false
    onCheckedChanged: {
      if (!root.localConfig.ThemeIntegrations)
        root.localConfig.ThemeIntegrations = {};
      root.localConfig.ThemeIntegrations.kitty = checked;
      root.markDirty();
    }
  }

  SchemaSwitch {
    label: "K9s Integration"
    checked: root.localConfig.ThemeIntegrations?.k9s || false
    onCheckedChanged: {
      if (!root.localConfig.ThemeIntegrations)
        root.localConfig.ThemeIntegrations = {};
      root.localConfig.ThemeIntegrations.k9s = checked;
      root.markDirty();
    }
  }

  SchemaSwitch {
    label: "Cava Integration"
    checked: root.localConfig.ThemeIntegrations?.cava || false
    onCheckedChanged: {
      if (!root.localConfig.ThemeIntegrations)
        root.localConfig.ThemeIntegrations = {};
      root.localConfig.ThemeIntegrations.cava = checked;
      root.markDirty();
    }
  }
}
