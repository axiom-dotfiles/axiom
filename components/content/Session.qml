pragma ComponentBehavior: Bound
import QtQuick
import qs.config
import qs.services
import qs.components.content.parts
import qs.components.reusable
import qs.components.content.base

// Lock, suspend, hibernate, log out, reboot and power off. The last three ask for a
// second click to confirm.
// properties: { actions: ["lock", "suspend", "hibernate", "logout", "reboot", "poweroff"] }
Card {
  id: root

  readonly property var actions: (root.properties.actions ?? ["lock", "suspend", "hibernate", "logout", "reboot", "poweroff"]).filter(a => ShellManager.sessionActionInfo(a) !== null)
  property string armed: ""

  function run(action) {
    if (ShellManager.destructiveActions.includes(action) && root.armed !== action) {
      root.armed = action;
      disarm.restart();
      return;
    }
    root.armed = "";
    ShellManager.sessionAction(action);
  }

  Timer {
    id: disarm
    interval: 3000
    onTriggered: root.armed = ""
  }

  TileGrid {
    id: grid
    anchors.fill: parent
    anchors.margins: root.pad
    count: root.actions.length

    Repeater {
      model: root.actions

      ActionTile {
        required property string modelData
        required property int index
        x: grid.tileX(index)
        y: grid.tileY(index)
        width: grid.tileWidth
        height: grid.tileHeight
        readonly property var info: ShellManager.sessionActionInfo(modelData)
        icon: info.icon
        label: active ? I18n.tr("Confirm?") : info.label
        showLabel: !root.compact
        active: root.armed === modelData
        activeColor: Theme.error
        tone: ShellManager.destructiveActions.includes(modelData) ? Theme.error : Theme.accent
        countdown: disarm.interval
        onClicked: root.run(modelData)
      }
    }
  }
}
