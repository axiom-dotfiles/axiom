pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import qs.config
import qs.components.reusable
import qs.components.methods

StyledContainer {
  id: root
  
  required property var keybind
  property var itemData
  property var iconLookupTbl: ({
    SHIFT: "󰘶",
    CTRL: "⌃",
    ALT: "ALT",
    SUPER: "󰘳",
    META: "󰘳",
  })
  
  // Container styling
  color: Theme.backgroundAlt
  implicitHeight: contentRow.implicitHeight + 16
  
  RowLayout {
    id: contentRow
    anchors.fill: parent
    anchors.margins: 8
    spacing: 12
    
    // Modifier keys
    RowLayout {
      spacing: 4
      
      Repeater {
        model: root.keybind.mod.split(" ")
        
        Rectangle {
          id: modRect
          required property var modelData
          Layout.preferredHeight: 28
          Layout.preferredWidth: modText.width + 16
          color: "transparent"
          visible: modText.text !== ""
          border.color: Theme.foreground
          border.width: Math.max(1, Appearance.borderWidth)
          radius: 4
          
          Text {
            id: modText
            anchors.centerIn: parent
            text: {
              // if (modRect.modelData.includ)
              const lookup = root.iconLookupTbl[modRect.modelData];
              return lookup !== undefined ? lookup : modRect.modelData.toUpperCase();
            }
            font.pixelSize: 20
            font.family: "monospace"
            color: Theme.foreground
          }
        }
      }
    }
    
    // Key bind
    Rectangle {
      Layout.preferredHeight: 28
      Layout.preferredWidth: bindText.width + 16
      color: "transparent"
      border.color: Theme.foreground
      border.width: Math.max(1, Appearance.borderWidth)
      radius: 4
      
      Text {
        id: bindText
        anchors.centerIn: parent
        text: root.keybind.bind.toUpperCase()
        font.pixelSize: 13
        font.family: "monospace"
        color: Theme.foreground
      }
    }
    
    // Action description
    Text {
      Layout.fillWidth: true
      Layout.alignment: Qt.AlignVCenter
      text: Utils.formatCommand(root.keybind.action);
      font.pixelSize: 14
      color: Theme.foreground
      opacity: 0.8
      elide: Text.ElideRight
      horizontalAlignment: Text.AlignRight
    }
  }
}
