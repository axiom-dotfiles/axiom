pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Io
import qs.config
import qs.services
import qs.components.content.parts
import qs.components.reusable
import qs.components.content.base

// A grid of toggle tiles. Toggles whose tool isn't installed (night light:
// hyprsunset/wlsunset, power saver: powerprofilesctl) are hidden.
// properties: { toggles: ["wifi", "bluetooth", "caffeine", "dnd", "darkMode", "nightLight", "powerSaver"] }
Card {
  id: root

  // Found once: which optional tools exist
  property string nightLightTool: ""
  property bool hasPowerProfiles: false
  property bool nightLightOn: false
  property string powerProfile: ""

  readonly property var defs: ({
      "wifi": {
        "icon": NetworkingManager.wifiEnabled ? "wifi" : "wifi_off",
        "label": I18n.tr("Wi-Fi"),
        "active": NetworkingManager.wifiEnabled,
        "available": NetworkingManager.available
      },
      "bluetooth": {
        "icon": BluetoothManager.enabled ? "bluetooth" : "bluetooth_disabled",
        "label": I18n.tr("Bluetooth"),
        "active": BluetoothManager.enabled,
        "available": BluetoothManager.available
      },
      "caffeine": {
        "icon": "coffee",
        "label": I18n.tr("Caffeine"),
        "active": IdleInhibitManager.enabled,
        "available": true
      },
      "dnd": {
        "icon": NotificationManager.dnd ? "notifications_off" : "notifications",
        "label": I18n.tr("Do not disturb"),
        "active": NotificationManager.dnd,
        "available": true
      },
      "darkMode": {
        "icon": "clear_night",
        "label": I18n.tr("Dark mode"),
        "active": Appearance.darkMode,
        "available": true
      },
      "nightLight": {
        "icon": "pill_off",
        "label": I18n.tr("Night light"),
        "active": root.nightLightOn,
        "available": root.nightLightTool !== ""
      },
      "powerSaver": {
        "icon": "eco",
        "label": I18n.tr("Power saver"),
        "active": root.powerProfile === "power-saver",
        "available": root.hasPowerProfiles
      }
    })

  // Config and tool availability only (never toggle state), so the tiles
  // aren't rebuilt whenever something is switched
  readonly property var known: ["wifi", "bluetooth", "caffeine", "dnd", "darkMode", "nightLight", "powerSaver"]
  readonly property var toggles: (root.properties.toggles ?? ["wifi", "bluetooth", "caffeine", "dnd", "darkMode"]).filter(t => root.known.includes(t))
  readonly property var shown: root.toggles.filter(t => t === "wifi" ? NetworkingManager.available : t === "bluetooth" ? BluetoothManager.available : t === "nightLight" ? root.nightLightTool !== "" : t === "powerSaver" ? root.hasPowerProfiles : true)

  function toggle(name) {
    switch (name) {
    case "wifi":
      NetworkingManager.toggleWifi();
      break;
    case "bluetooth":
      BluetoothManager.toggleEnabled();
      break;
    case "caffeine":
      IdleInhibitManager.toggle();
      break;
    case "dnd":
      NotificationManager.dnd = !NotificationManager.dnd;
      break;
    case "darkMode":
      ThemeManager.toggleDarkMode();
      break;
    case "nightLight":
      if (root.nightLightOn)
        Quickshell.execDetached(["pkill", "-x", root.nightLightTool]);
      else
        Quickshell.execDetached(root.nightLightTool === "hyprsunset" ? ["hyprsunset", "-t", "4500"] : ["wlsunset", "-t", "4500"]);
      root.nightLightOn = !root.nightLightOn;
      break;
    case "powerSaver":
      {
        const next = root.powerProfile === "power-saver" ? "balanced" : "power-saver";
        Quickshell.execDetached(["powerprofilesctl", "set", next]);
        root.powerProfile = next;
      }
      break;
    }
  }

  Process {
    running: true
    command: ["sh", "-c", `
      for t in hyprsunset wlsunset; do command -v $t >/dev/null && { echo "night $t"; pgrep -x $t >/dev/null && echo "nighton 1"; break; }; done
      command -v powerprofilesctl >/dev/null && echo "profile $(powerprofilesctl get)"
      true
    `]
    stdout: StdioCollector {
      onStreamFinished: {
        for (const line of text.trim().split("\n")) {
          const [key, value] = line.split(" ");
          if (key === "night")
            root.nightLightTool = value;
          else if (key === "nighton")
            root.nightLightOn = true;
          else if (key === "profile") {
            root.hasPowerProfiles = true;
            root.powerProfile = value;
          }
        }
      }
    }
  }

  TileGrid {
    id: grid
    anchors.fill: parent
    anchors.margins: root.pad
    count: root.shown.length

    Repeater {
      model: root.shown

      ActionTile {
        required property string modelData
        required property int index
        readonly property var def: root.defs[modelData]
        x: grid.tileX(index)
        y: grid.tileY(index)
        width: grid.tileWidth
        height: grid.tileHeight
        icon: def.icon
        label: def.label
        active: def.active
        showLabel: !root.compact
        onClicked: root.toggle(modelData)
      }
    }
  }
}
