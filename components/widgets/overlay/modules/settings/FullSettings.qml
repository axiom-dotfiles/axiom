// SettingsMenu.qml
pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import qs.config
import qs.services
import qs.components.widgets.common
import qs.components.widgets.overlay.modules.settings

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
  property var localConfig: ({})
  property bool isDirty: false
  property bool isStaged: false
  
  Component.onCompleted: {
    loadConfig()
  }
  
  function loadConfig() {
    // Deep copy
    localConfig = JSON.parse(JSON.stringify(ConfigManager.config))
    isDirty = false
    isStaged = false
  }
  
  function markDirty() {
    if (!isDirty) {
      isDirty = true
    }
  }
  
  function stageChanges() {
    ConfigManager.stageConfig(localConfig)
    isStaged = true
    isDirty = false
  }
  
  function unstageChanges() {
    ConfigManager.forceReload()
    isStaged = false
  }
  
  function saveChanges() {
    ConfigManager.saveConfig()
    isStaged = false
    isDirty = false
    loadConfig()
  }
  
  function resetChanges() {
    loadConfig()
    if (isStaged) {
      ConfigManager.forceReload()
    }
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
        
        Item { height: Widget.spacing }
        
        
        GeneralSettings {}
        AppearanceSettings {}
        SchemaSection {
          title: "Widget"
          Layout.leftMargin: Widget.padding
          Layout.rightMargin: Widget.padding
          
          GridLayout {
            Layout.fillWidth: true
            columns: 3
            columnSpacing: Widget.spacing
            rowSpacing: Widget.spacing
            
            SchemaSpinBox {
              label: "Widget Height"
              value: root.localConfig.Widget?.height || 32
              minimum: 16
              maximum: 128
              onValueChanged: {
                if (!root.localConfig.Widget) root.localConfig.Widget = {}
                root.localConfig.Widget.height = value
                root.markDirty()
              }
            }
            
            SchemaSpinBox {
              label: "Widget Padding"
              value: root.localConfig.Widget?.padding || 8
              minimum: 0
              maximum: 32
              onValueChanged: {
                if (!root.localConfig.Widget) root.localConfig.Widget = {}
                root.localConfig.Widget.padding = value
                root.markDirty()
              }
            }
            
            SchemaSpinBox {
              label: "Widget Spacing"
              value: root.localConfig.Widget?.spacing || 8
              minimum: 0
              maximum: 32
              onValueChanged: {
                if (!root.localConfig.Widget) root.localConfig.Widget = {}
                root.localConfig.Widget.spacing = value
                root.markDirty()
              }
            }
            
            SchemaSpinBox {
              label: "Border Width"
              value: root.localConfig.Widget?.borderWidth || 1
              minimum: 0
              maximum: 10
              onValueChanged: {
                if (!root.localConfig.Widget) root.localConfig.Widget = {}
                root.localConfig.Widget.borderWidth = value
                root.markDirty()
              }
            }
            
            SchemaSpinBox {
              label: "Container Width"
              value: root.localConfig.Widget?.containerWidth || 200
              minimum: 100
              maximum: 1000
              onValueChanged: {
                if (!root.localConfig.Widget) root.localConfig.Widget = {}
                root.localConfig.Widget.containerWidth = value
                root.markDirty()
              }
            }
            
            SchemaSpinBox {
              label: "Animation Duration"
              value: root.localConfig.Widget?.animationDuration || 200
              minimum: 0
              maximum: 1000
              description: "Duration in milliseconds"
              onValueChanged: {
                if (!root.localConfig.Widget) root.localConfig.Widget = {}
                root.localConfig.Widget.animationDuration = value
                root.markDirty()
              }
            }
          }
          
          SchemaSwitch {
            label: "Enable Animations"
            checked: root.localConfig.Widget?.animations !== undefined ? root.localConfig.Widget.animations : true
            onCheckedChanged: {
              if (!root.localConfig.Widget) root.localConfig.Widget = {}
              root.localConfig.Widget.animations = checked
              root.markDirty()
            }
          }
          
          SchemaSwitch {
            label: "Workspace Popout Icons"
            checked: root.localConfig.Widget?.workspacePopoutIcons || false
            description: "Show icons outside workspace container"
            onCheckedChanged: {
              if (!root.localConfig.Widget) root.localConfig.Widget = {}
              root.localConfig.Widget.workspacePopoutIcons = checked
              root.markDirty()
            }
          }
        }
        
        ChatSettings {}
        IntegrationSettings {}
        Item { height: Widget.spacing * 2 }
      }
    }
  }
}
