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
  
  // Main layout
  ColumnLayout {
    anchors.fill: parent
    anchors.margins: Widget.padding
    spacing: 0
    
    SettingsHeader {}
    
    // Divider
    Rectangle {
      Layout.fillWidth: true
      Layout.preferredHeight: 1
      Layout.topMargin: Widget.spacing / 2
      Layout.bottomMargin: Widget.spacing / 2
      color: Theme.border
      opacity: 0.3
    }
    
    // Content area
    ScrollView {
      Layout.fillWidth: true
      Layout.fillHeight: true
      clip: true
      ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
      
      ColumnLayout {
        width: parent.parent.width - Widget.padding * 2
        spacing: Widget.spacing * 2
        
        Item { height: Widget.spacing }
        
        // General
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
              if (!root.localConfig.Config) root.localConfig.Config = {}
              root.localConfig.Config.userName = value
              root.markDirty()
            }
          }
          
          SchemaSpinBox {
            label: "Workspace Count"
            value: root.localConfig.Config?.workspaceCount || 4
            minimum: 1
            maximum: 10
            description: "Number of virtual workspaces"
            onValueChanged: {
              if (!root.localConfig.Config) root.localConfig.Config = {}
              root.localConfig.Config.workspaceCount = value
              root.markDirty()
            }
          }
          
          SchemaSwitch {
            label: "Single Monitor Mode"
            checked: root.localConfig.Config?.singleMonitor || false
            description: "Optimize for single display"
            onCheckedChanged: {
              if (!root.localConfig.Config) root.localConfig.Config = {}
              root.localConfig.Config.singleMonitor = checked
              root.markDirty()
            }
          }
        }
        
        // Appearance
        SchemaSection {
          title: "Appearance"
          Layout.leftMargin: Widget.padding
          Layout.rightMargin: Widget.padding
          
          SchemaTextField {
            label: "Theme Name"
            value: root.localConfig.Appearance?.theme || ""
            placeholderText: "default"
            onValueChanged: {
              if (!root.localConfig.Appearance) root.localConfig.Appearance = {}
              root.localConfig.Appearance.theme = value
              root.markDirty()
            }
          }
          
          SchemaSwitch {
            label: "Dark Mode"
            checked: root.localConfig.Appearance?.darkMode || false
            onCheckedChanged: {
              if (!root.localConfig.Appearance) root.localConfig.Appearance = {}
              root.localConfig.Appearance.darkMode = checked
              root.markDirty()
            }
          }
          
          SchemaSwitch {
            label: "Auto Theme Switch"
            checked: root.localConfig.Appearance?.autoThemeSwitch || false
            description: "Automatically switch between light/dark"
            onCheckedChanged: {
              if (!root.localConfig.Appearance) root.localConfig.Appearance = {}
              root.localConfig.Appearance.autoThemeSwitch = checked
              root.markDirty()
            }
          }
          
          GridLayout {
            Layout.fillWidth: true
            columns: 3
            columnSpacing: Widget.spacing
            rowSpacing: Widget.spacing
            
            SchemaSpinBox {
              label: "Border Radius"
              value: root.localConfig.Appearance?.borderRadius || 8
              minimum: 0
              maximum: 50
              description: "Roundness of corners (px)"
              onValueChanged: {
                if (!root.localConfig.Appearance) root.localConfig.Appearance = {}
                root.localConfig.Appearance.borderRadius = value
                root.markDirty()
              }
            }
            
            SchemaSpinBox {
              label: "Border Width"
              value: root.localConfig.Appearance?.borderWidth || 1
              minimum: 0
              maximum: 10
              description: "Thickness of borders (px)"
              onValueChanged: {
                if (!root.localConfig.Appearance) root.localConfig.Appearance = {}
                root.localConfig.Appearance.borderWidth = value
                root.markDirty()
              }
            }
            
            SchemaSpinBox {
              label: "Screen Margin"
              value: root.localConfig.Appearance?.screenMargin || 0
              minimum: 0
              maximum: 100
              description: "Space around screen edges (px)"
              onValueChanged: {
                if (!root.localConfig.Appearance) root.localConfig.Appearance = {}
                root.localConfig.Appearance.screenMargin = value
                root.markDirty()
              }
            }
          }
          
          SchemaTextField {
            label: "Font Family"
            value: root.localConfig.Appearance?.fontFamily || "Inter"
            placeholderText: "Font name"
            onValueChanged: {
              if (!root.localConfig.Appearance) root.localConfig.Appearance = {}
              root.localConfig.Appearance.fontFamily = value
              root.markDirty()
            }
          }
          
          SchemaSpinBox {
            label: "Font Size"
            value: root.localConfig.Appearance?.fontSize || 12
            minimum: 8
            maximum: 24
            description: "Base font size (px)"
            onValueChanged: {
              if (!root.localConfig.Appearance) root.localConfig.Appearance = {}
              root.localConfig.Appearance.fontSize = value
              root.markDirty()
            }
          }
        }
        
        // Widget
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
        
        // Bar
        SchemaSection {
          title: "Bar"
          description: "Configure your status bars and their widgets"
          Layout.leftMargin: Widget.padding
          Layout.rightMargin: Widget.padding
          
          SchemaObjectArray {
            label: "Bars"
            items: root.localConfig.Bar || []
            description: "Add and configure multiple bars"
            onItemsChanged: {
              root.localConfig.Bar = items
              root.markDirty()
            }
            
            itemDelegate: Component {
              ColumnLayout {
                property var itemData
                property int itemIndex
                spacing: Widget.spacing
                
                SchemaTextField {
                  label: "Bar ID"
                  value: itemData?.id || ""
                  placeholderText: "bar-1"
                  onValueChanged: {
                    if (itemData) itemData.id = value
                    root.markDirty()
                  }
                }
                
                SchemaSwitch {
                  label: "Enabled"
                  checked: itemData?.enabled || false
                  onCheckedChanged: {
                    if (itemData) itemData.enabled = checked
                    root.markDirty()
                  }
                }
                
                SchemaSwitch {
                  label: "Primary Bar"
                  checked: itemData?.primary || false
                  onCheckedChanged: {
                    if (itemData) itemData.primary = checked
                    root.markDirty()
                  }
                }
                
                SchemaComboBox {
                  label: "Location"
                  options: ["Top", "Bottom", "Left", "Right"]
                  currentValue: itemData?.location || "Top"
                  onCurrentValueChanged: {
                    if (itemData) itemData.location = currentValue
                    root.markDirty()
                  }
                }
                
                SchemaSpinBox {
                  label: "Bar Height/Width"
                  value: itemData?.extent || 32
                  minimum: 16
                  maximum: 128
                  onValueChanged: {
                    if (itemData) itemData.extent = value
                    root.markDirty()
                  }
                }
                
                SchemaSpinBox {
                  label: "Widget Spacing"
                  value: itemData?.spacing || 8
                  minimum: 0
                  maximum: 32
                  onValueChanged: {
                    if (itemData) itemData.spacing = value
                    root.markDirty()
                  }
                }
                
                SchemaSwitch {
                  label: "Auto Hide"
                  checked: itemData?.autoHide || false
                  onCheckedChanged: {
                    if (itemData) itemData.autoHide = checked
                    root.markDirty()
                  }
                }
              }
            }
          }
        }
        
        // Menu
        SchemaSection {
          title: "Menu"
          Layout.leftMargin: Widget.padding
          Layout.rightMargin: Widget.padding
          
          SchemaSwitch {
            label: "Enable Menu"
            checked: root.localConfig.Menu?.enabled !== undefined ? root.localConfig.Menu.enabled : true
            onCheckedChanged: {
              if (!root.localConfig.Menu) root.localConfig.Menu = {}
              root.localConfig.Menu.enabled = checked
              root.markDirty()
            }
          }
          
          SchemaSpinBox {
            label: "Distance from Workspace"
            value: root.localConfig.Menu?.distanceFromWorkspaceContainer || 10
            minimum: 0
            maximum: 100
            description: "Spacing in pixels"
            onValueChanged: {
              if (!root.localConfig.Menu) root.localConfig.Menu = {}
              root.localConfig.Menu.distanceFromWorkspaceContainer = value
              root.markDirty()
            }
          }
        }
        
        // Chat
        SchemaSection {
          title: "Chat"
          Layout.leftMargin: Widget.padding
          Layout.rightMargin: Widget.padding
          
          SchemaSwitch {
            label: "Enable Chat"
            checked: root.localConfig.ChatConfig?.enabled || false
            onCheckedChanged: {
              if (!root.localConfig.ChatConfig) root.localConfig.ChatConfig = {}
              root.localConfig.ChatConfig.enabled = checked
              root.markDirty()
            }
          }
          
          SchemaComboBox {
            label: "Default Backend"
            options: ["gemini", "anthropic", "openai"]
            currentValue: root.localConfig.ChatConfig?.defaultBackend || "openai"
            onCurrentValueChanged: {
              if (!root.localConfig.ChatConfig) root.localConfig.ChatConfig = {}
              root.localConfig.ChatConfig.defaultBackend = currentValue
              root.markDirty()
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
              if (!root.localConfig.ChatConfig) root.localConfig.ChatConfig = {}
              root.localConfig.ChatConfig.backends = pairs
              root.markDirty()
            }
          }
        }
        
        // Theme Integrations
        SchemaSection {
          title: "Theme Integrations"
          description: "Sync theme with external applications"
          Layout.leftMargin: Widget.padding
          Layout.rightMargin: Widget.padding
          
          SchemaSwitch {
            label: "GTK Integration"
            checked: root.localConfig.ThemeIntegrations?.gtk || false
            onCheckedChanged: {
              if (!root.localConfig.ThemeIntegrations) root.localConfig.ThemeIntegrations = {}
              root.localConfig.ThemeIntegrations.gtk = checked
              root.markDirty()
            }
          }
          
          SchemaSwitch {
            label: "Neovim Integration"
            checked: root.localConfig.ThemeIntegrations?.nvim || false
            onCheckedChanged: {
              if (!root.localConfig.ThemeIntegrations) root.localConfig.ThemeIntegrations = {}
              root.localConfig.ThemeIntegrations.nvim = checked
              root.markDirty()
            }
          }
          
          SchemaSwitch {
            label: "VS Code Integration"
            checked: root.localConfig.ThemeIntegrations?.vscode || false
            onCheckedChanged: {
              if (!root.localConfig.ThemeIntegrations) root.localConfig.ThemeIntegrations = {}
              root.localConfig.ThemeIntegrations.vscode = checked
              root.markDirty()
            }
          }
          
          SchemaSwitch {
            label: "Alacritty Integration"
            checked: root.localConfig.ThemeIntegrations?.alacritty || false
            onCheckedChanged: {
              if (!root.localConfig.ThemeIntegrations) root.localConfig.ThemeIntegrations = {}
              root.localConfig.ThemeIntegrations.alacritty = checked
              root.markDirty()
            }
          }
          
          SchemaSwitch {
            label: "Kitty Integration"
            checked: root.localConfig.ThemeIntegrations?.kitty || false
            onCheckedChanged: {
              if (!root.localConfig.ThemeIntegrations) root.localConfig.ThemeIntegrations = {}
              root.localConfig.ThemeIntegrations.kitty = checked
              root.markDirty()
            }
          }
          
          SchemaSwitch {
            label: "K9s Integration"
            checked: root.localConfig.ThemeIntegrations?.k9s || false
            onCheckedChanged: {
              if (!root.localConfig.ThemeIntegrations) root.localConfig.ThemeIntegrations = {}
              root.localConfig.ThemeIntegrations.k9s = checked
              root.markDirty()
            }
          }
          
          SchemaSwitch {
            label: "Cava Integration"
            checked: root.localConfig.ThemeIntegrations?.cava || false
            onCheckedChanged: {
              if (!root.localConfig.ThemeIntegrations) root.localConfig.ThemeIntegrations = {}
              root.localConfig.ThemeIntegrations.cava = checked
              root.markDirty()
            }
          }
        }
        
        Item { height: Widget.spacing * 2 }
      }
    }
  }
}
