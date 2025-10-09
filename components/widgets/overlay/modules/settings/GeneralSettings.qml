pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import qs.config
import qs.components.widgets.common

SchemaSection {
  title: "General"
  Layout.leftMargin: Widget.padding
  Layout.rightMargin: Widget.padding

  SchemaTextField {
    label: "User Name"
    value: root.localConfig.Config?.userName || ""
    placeholderText: "Enter your name"
    description: "Your display name"
    onValueChanged: {
      if (!root.localConfig.Config)
        root.localConfig.Config = {};
      root.localConfig.Config.userName = value;
      root.markDirty();
    }
  }

  SchemaSpinBox {
    label: "Workspace Count"
    value: root.localConfig.Config?.workspaceCount || 4
    minimum: 1
    maximum: 10
    description: "Number of virtual workspaces"
    onValueChanged: {
      if (!root.localConfig.Config)
        root.localConfig.Config = {};
      root.localConfig.Config.workspaceCount = value;
      root.markDirty();
    }
  }

  SchemaSwitch {
    label: "Single Monitor Mode"
    checked: root.localConfig.Config?.singleMonitor || false
    description: "Optimize for single display"
    onCheckedChanged: {
      if (!root.localConfig.Config)
        root.localConfig.Config = {};
      root.localConfig.Config.singleMonitor = checked;
      root.markDirty();
    }
  }
}
