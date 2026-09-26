pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Io
import qs.config
import qs.services
import qs.components.content.parts
import qs.components.reusable
import qs.components.content.base

// A grid of action tiles: toggles, session actions and pin, in any mix.
// Tiles that can't work here are hidden: night light (hyprsunset/wlsunset)
// and power saver (powerprofilesctl) without their tool, pin outside an
// edge menu. Log out, reboot and power off ask for a second click.
// Names show on every tile or none ("auto": only when all fit whole),
// always ("show", elided) or never ("hide").
// properties: { actions: ["wifi", "bluetooth", "caffeine", "dnd", "darkMode", "nightLight", "powerSaver",
//                         "lock", "suspend", "hibernate", "logout", "reboot", "poweroff", "pin"],
//               labels: "auto" | "show" | "hide" }
Card {
  id: root

  // Found once: which optional tools exist
  property string nightLightTool: ""
  property bool hasPowerProfiles: false
  property bool nightLightOn: false
  property string powerProfile: ""
  property string armed: ""

  readonly property bool inMenu: root.host?.kind === "edgeMenu" && !!root.host.id
  readonly property bool pinned: root.inMenu && EdgeMenuManager.pinnedMenus[root.host.id] === true

  readonly property var sessionActions: ["lock", "suspend", "hibernate", "logout", "reboot", "poweroff"]

  readonly property var defs: ({
      "wifi": {
        "icon": NetworkingManager.wifiEnabled ? "wifi" : "wifi_off",
        "label": I18n.tr("Wi-Fi"),
        "active": NetworkingManager.wifiEnabled
      },
      "bluetooth": {
        "icon": BluetoothManager.enabled ? "bluetooth" : "bluetooth_disabled",
        "label": I18n.tr("Bluetooth"),
        "active": BluetoothManager.enabled
      },
      "caffeine": {
        "icon": "coffee",
        "label": I18n.tr("Caffeine"),
        "active": IdleInhibitManager.enabled
      },
      "dnd": {
        "icon": NotificationManager.dnd ? "notifications_off" : "notifications",
        "label": I18n.tr("Do not disturb"),
        "active": NotificationManager.dnd
      },
      "darkMode": {
        "icon": "clear_night",
        "label": I18n.tr("Dark mode"),
        "active": Appearance.darkMode
      },
      "nightLight": {
        "icon": "pill_off",
        "label": I18n.tr("Night light"),
        "active": root.nightLightOn
      },
      "powerSaver": {
        "icon": "eco",
        "label": I18n.tr("Power saver"),
        "active": root.powerProfile === "power-saver"
      },
      "pin": {
        "icon": "push_pin",
        "label": root.pinned ? I18n.tr("Pinned") : I18n.tr("Pin open"),
        "active": root.pinned
      }
    })

  function def(name) {
    if (!root.sessionActions.includes(name))
      return root.defs[name];
    const info = ShellManager.sessionActionInfo(name);
    const destructive = ShellManager.destructiveActions.includes(name);
    return {
      "icon": info.icon,
      "label": root.armed === name ? I18n.tr("Confirm?") : info.label,
      "active": root.armed === name,
      "destructive": destructive,
      "tone": destructive ? Theme.error : Theme.accent
    };
  }

  // Config, tool availability and host only (never toggle state), so the
  // tiles aren't rebuilt whenever something is switched
  readonly property var known: Object.keys(root.defs).concat(root.sessionActions)
  readonly property var actions: (root.properties.actions ?? ["wifi", "bluetooth", "caffeine", "dnd", "darkMode"]).filter(a => root.known.includes(a))
  readonly property var shown: root.actions.filter(a => {
    switch (a) {
    case "wifi":
      return NetworkingManager.available;
    case "bluetooth":
      return BluetoothManager.available;
    case "nightLight":
      return root.nightLightTool !== "";
    case "powerSaver":
      return root.hasPowerProfiles;
    case "pin":
      return root.inMenu;
    default:
      return !root.sessionActions.includes(a) || ShellManager.sessionActionInfo(a) !== null;
    }
  })

  // Every tile is the same size, so the names all fit when the widest does
  // (ActionTile.labelFits, measured in its label font)
  readonly property string labels: root.properties.labels ?? "auto"
  // "Confirm?" counts for the actions that ask, so arming one doesn't hide
  // every name
  readonly property var _fitLabels: root.shown.map(a => root.def(a).label).concat(root.shown.some(a => ShellManager.destructiveActions.includes(a)) ? [I18n.tr("Confirm?")] : [])
  readonly property real widestLabel: Math.max(0, ...root._fitLabels.map(label => labelFont.advanceWidth(label)))
  readonly property bool labelsFit: root.widestLabel <= grid.tileWidth - Widget.spacing * 2 && grid.tileHeight >= Appearance.fontSize * 4.5

  FontMetrics {
    id: labelFont
    font.family: Appearance.fontFamily
    font.pixelSize: Appearance.fontSize - 1
  }

  function run(name) {
    if (root.sessionActions.includes(name)) {
      if (ShellManager.destructiveActions.includes(name) && root.armed !== name) {
        root.armed = name;
        disarm.restart();
        return;
      }
      root.armed = "";
      ShellManager.sessionAction(name);
      return;
    }
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
    case "pin":
      EdgeMenuManager.togglePinned(root.host.id);
      break;
    }
  }

  Timer {
    id: disarm
    interval: 3000
    onTriggered: root.armed = ""
  }

  Process {
    running: root.actions.includes("nightLight") || root.actions.includes("powerSaver")
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
        readonly property var def: root.def(modelData)
        x: grid.tileX(index)
        y: grid.tileY(index)
        width: grid.tileWidth
        height: grid.tileHeight
        icon: def.icon
        label: def.label
        active: def.active
        showLabel: root.labels === "show" || (root.labels === "auto" && root.labelsFit)
        forceLabel: root.labels === "show"
        activeColor: def.destructive ? Theme.error : Theme.accent
        tone: def.tone ?? activeColor
        countdown: def.destructive ? disarm.interval : 0
        onClicked: root.run(modelData)
      }
    }
  }
}
