pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import qs.config
import qs.components.widgets.common

SchemaSection {
  title: "Chat"
  Layout.leftMargin: Widget.padding
  Layout.rightMargin: Widget.padding

  SchemaSwitch {
    label: "Enable Chat"
    checked: root.localConfig.ChatConfig?.enabled || false
    onCheckedChanged: {
      if (!root.localConfig.ChatConfig)
        root.localConfig.ChatConfig = {};
      root.localConfig.ChatConfig.enabled = checked;
      root.markDirty();
    }
  }

  SchemaComboBox {
    label: "Default Backend"
    options: ["gemini", "anthropic", "openai"]
    currentValue: root.localConfig.ChatConfig?.defaultBackend || "openai"
    onCurrentValueChanged: {
      if (!root.localConfig.ChatConfig)
        root.localConfig.ChatConfig = {};
      root.localConfig.ChatConfig.defaultBackend = currentValue;
      root.markDirty();
    }
  }

  SchemaKeyValueEditor {
    label: "Backend Configurations"
    pairs: root.localConfig.ChatConfig?.backends || {}
    keyPlaceholder: "Backend name"
    valuePlaceholder: "Configuration JSON"
    keyPattern: "^[a-zA-Z0-9_]+$"
    description: "Configure API backends for chat"
    onPairsChanged: {
      if (!root.localConfig.ChatConfig)
        root.localConfig.ChatConfig = {};
      root.localConfig.ChatConfig.backends = pairs;
      root.markDirty();
    }
  }
}
