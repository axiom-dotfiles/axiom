pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import qs.config
import qs.services
import qs.components.widgets.common
import qs.components.reusable

Rectangle {
  id: root

  // --- PROPERTIES ---

  // The main model containing all keybind categories
  // e.g., { "WINDOW": [...], "WORKSPACE": [...], "OTHER": [...] }
  required property var keybinds
  required property var screen

  // Defines the order in which sections will be displayed
  property var sectionOrder: ["WINDOW", "WORKSPACE", "OTHER"]

  // A flat list model that will be built from the 'keybinds' object.
  // This is used by the Repeater to create a continuous flow.
  property list<var> displayModel: []

  // --- STYLING ---

  radius: Menu.cardBorderRadius
  color: Theme.background
  // highly likely to break
  // kind illegal to access this here (kinda abusing qml context properties)
  implicitHeight: screen.height - 300 // TODO: magix num
  implicitWidth: flow.implicitWidth + (Menu.cardSpacing * 2)

  border.color: Theme.border
  border.width: Menu.cardBorderWidth


  // --- JAVASCRIPT LOGIC ---
  function formatTitle(key) {
    if (!key || typeof key !== 'string') return "";
    let formatted = key.charAt(0).toUpperCase() + key.slice(1).toLowerCase();
    
    if (key === "WINDOW" || key === "WORKSPACE" || key === "MODIFIERS") {
        return formatted + " Management";
    }
    return formatted;
  }

  // This function transforms the structured 'keybinds' object into a
  // flat list ('displayModel') for the Repeater, merging keybinds with the same action.
  function buildDisplayModel() {
    var newModel = [];
    for (const sectionKey of sectionOrder) {
      if (keybinds && keybinds.hasOwnProperty(sectionKey) && keybinds[sectionKey].length > 0) {
        
        // Add header item
        newModel.push({
          type: "header",
          title: formatTitle(sectionKey)
        });

        // Group keybinds by action
        const groupedKeybinds = {};
        for (const keybindItem of keybinds[sectionKey]) {
            const action = keybindItem.action;
            if (!groupedKeybinds[action]) {
                groupedKeybinds[action] = [];
            }
            groupedKeybinds[action].push({
                mod: keybindItem.mod,
                bind: keybindItem.bind
            });
        }

        // Add merged keybind items for the current section
        for (const action in groupedKeybinds) {
            if (groupedKeybinds.hasOwnProperty(action)) {
                newModel.push({
                    type: "keybind",
                    data: {
                        action: action,
                        binds: groupedKeybinds[action]
                    }
                });
            }
        }
      }
    }
    displayModel = newModel;
  }

  onKeybindsChanged: buildDisplayModel()
  Component.onCompleted: buildDisplayModel()

  // --- LAYOUT ---
  Flow {
    id: flow
    anchors.fill: parent
    anchors.margins: Menu.cardSpacing
    flow: Flow.TopToBottom
    spacing: Menu.cardPadding

    Repeater {
      model: root.displayModel
      delegate: Loader {
        id: itemLoader
        width: Menu.cardUnit
        required property var modelData

        sourceComponent: {
          switch(modelData.type) {
            case "header": return headerComponent;
            case "separator": return separatorComponent;
            case "keybind": return keybindComponent;
            default: return null;
          }
        }
        onLoaded: {
          if (item) {
            item.itemData = itemLoader.modelData;
          }
        }
      }
    }
  }

  Component {
    id: headerComponent
    StyledContainer {
      id: header
      property var itemData
      width: Menu.cardUnit
      color: Theme.backgroundHighlight
      height: 32
      StyledText {
        anchors.centerIn: parent
        text: header.itemData.title
        
        font.bold: true
        color: Theme.accent
      }
      
      Rectangle {
        anchors.bottom: parent.bottom
        anchors.horizontalCenter: parent.horizontalCenter
        width: parent.width - (Menu.cardPadding * 2)
        height: 1
        anchors.rightMargin: Widget.padding
        anchors.leftMargin: Menu.cardPadding
        color: Theme.info
      }
    }
  }

  Component {
    id: separatorComponent
    StyledContainer {
      width: Menu.cardUnit - (Menu.cardPadding * 2)
      height: 1
      color: Theme.border
      anchors.bottomMargin: 8
    }
  }

  Component {
    id: keybindComponent
    KeybindPreview {
      width: Menu.cardUnit
      anchors.topMargin: 4
      anchors.bottomMargin: 4
    }
  }
}
