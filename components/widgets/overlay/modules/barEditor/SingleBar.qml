pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import qs.config
import qs.services
import qs.components.widgets.common
import qs.components.widgets.overlay.modules.settings

SchemaSection {
  id: root

  required property var localConfig

  title: modelData.display
  expanded: true

  Layout.leftMargin: Widget.padding
  Layout.rightMargin: Widget.padding
  ColumnLayout {
    Layout.fillWidth: true
    spacing: Widget.spacing

    SchemaSwitch {
      label: "Enabled"
      checked: root.localConfig.enabled || false
      description: "Enable or disable this bar"
    }

    SchemaSpinBox {
      label: "Extent"
      description: "Extent of the bar (px)"
      currentConfigValue: root.localConfig.extent || 30
      minimum: 10
      maximum: 200
      onValueChanged: {
        root.localConfig.height = value;
      }
    }

    SchemaSpinBox {
      label: "Spacing"
      description: "Spacing between widgets in the bar (px)"
      currentConfigValue: root.localConfig.spacing || 5
      minimum: 0
      maximum: 50
      onValueChanged: {
        BarManager.previewConfig.spacing = value;
      }
    }
  }
}
