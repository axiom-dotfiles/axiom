pragma ComponentBehavior: Bound
import QtQuick
import qs.config
import qs.services
import qs.components.content.parts
import qs.components.content.base

// Lock, suspend, hibernate, log out, reboot and power off. The last three ask for a
// second click to confirm.
// properties: { actions: ["lock", "suspend", "hibernate", "logout", "reboot", "poweroff"] }
Card {
  id: root

  readonly property var defs: ({
      "lock": ["lock", I18n.tr("Lock")],
      "suspend": ["sleep", I18n.tr("Suspend")],
      "hibernate": ["ac_unit", I18n.tr("Hibernate")],
      "logout": ["logout", I18n.tr("Log out")],
      "reboot": ["restart_alt", I18n.tr("Reboot")],
      "poweroff": ["power_settings_new", I18n.tr("Power off")]
    })
  readonly property var actions: (root.properties.actions ?? ["lock", "suspend", "hibernate", "logout", "reboot", "poweroff"]).filter(a => a in root.defs)
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

      IconToggle {
        required property string modelData
        required property int index
        x: grid.tileX(index)
        y: grid.tileY(index)
        width: grid.tileWidth
        height: grid.tileHeight
        icon: root.defs[modelData][0]
        label: active ? I18n.tr("Confirm?") : root.defs[modelData][1]
        showLabel: !root.compact
        active: root.armed === modelData
        activeColor: Theme.error
        onClicked: root.run(modelData)
      }
    }
  }
}
