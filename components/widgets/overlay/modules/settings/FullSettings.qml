// SettingsMenu.qml
pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import qs.config
import qs.services
import qs.components.widgets.common
import qs.components.widgets.overlay.modules.settings

// TODO: Fix bindings and whatnot. Not exaclty the biggest fan of the state management here

/**
 * Main settings menu component - fits in square grid cell
 */
Rectangle {
  id: root
  color: Theme.background
  radius: Menu.cardBorderRadius
  anchors.fill: parent
  border.color: Theme.border
  border.width: Appearance.borderWidth

  // Local state management
  property var localConfig: SettingsMenu.localConfig
  property bool isDirty: SettingsMenu.isDirty
  property bool isStaged: SettingsMenu.isStaged

  Component.onCompleted: {
    SettingsMenu.loadConfig();
  }

  onIsDirtyChanged: {
    console.log("SettingsMenu dirty changed to", isDirty);
  }

  ColumnLayout {
    anchors.fill: parent
    anchors.margins: Widget.padding
    spacing: 0

    SettingsHeader {}

    Rectangle {
      Layout.fillWidth: true
      Layout.preferredHeight: 1
      Layout.topMargin: Widget.spacing / 2
      Layout.bottomMargin: Widget.spacing / 2
      color: Theme.border
      opacity: 0.3
    }

    ScrollView {
      Layout.fillWidth: true
      Layout.fillHeight: true
      clip: true
      ScrollBar.horizontal.policy: ScrollBar.AlwaysOff

      ColumnLayout {
        width: parent.parent.width - Widget.padding * 2
        spacing: Widget.spacing * 2

        Item {
          height: Widget.spacing
        }

        // GeneralSettings {}
        AppearanceSettings {
          localConfig: root.localConfig
        }
        SchemaSection {
          title: "Widget"
          Layout.leftMargin: Widget.padding
          Layout.rightMargin: Widget.padding

          GridLayout {
            Layout.fillWidth: true
            columns: 1
            columnSpacing: Widget.spacing
            rowSpacing: Widget.spacing

            SchemaSpinBox {
              label: "Height"
              currentConfigValue: root.localConfig.Widget?.height || 0
              minimum: 16
              maximum: 128
              onValueChanged: {
                if (!root.localConfig.Widget)
                  root.localConfig.Widget = {};
                root.localConfig.Widget.height = value;
                SettingsMenu.continueStaging();
              }
              onIsDirtyChanged: {
                SettingsMenu.markDirty();
              }
            }

            SchemaSpinBox {
              id: paddingSpinBox
              label: "Padding"
              currentConfigValue: root.localConfig.Widget?.padding || 0
              minimum: 0
              maximum: 32
              onValueChanged: {
                if (!root.localConfig.Widget)
                  root.localConfig.Widget = {};
                root.localConfig.Widget.padding = value;
                SettingsMenu.continueStaging();
              }
              onIsDirtyChanged: {
                SettingsMenu.markDirty();
              }
            }

            SchemaSpinBox {
              label: "Spacing"
              currentConfigValue: root.localConfig.Widget?.spacing || 0
              minimum: 0
              maximum: 32
              onValueChanged: {
                if (!root.localConfig.Widget)
                  root.localConfig.Widget = {};
                root.localConfig.Widget.spacing = value;
                SettingsMenu.continueStaging();
              }
              onIsDirtyChanged: {
                SettingsMenu.markDirty();
              }
            }
          }
        }

        // ChatSettings {}
        // IntegrationSettings {}
        // Item {
        // }
      }
    }
  }
}
