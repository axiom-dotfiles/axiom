pragma ComponentBehavior: Bound
import QtQuick
import qs.config
import qs.services

// The bar editor's widget area (sections board and inspector). Owns the one
// drag in progress and its ghost, drawn above both so a widget can be
// carried out of the library or from one section to another. Lanes
// register themselves to be hit-tested; chips report their pointer here.
Item {
  id: root

  default property alias content: contentItem.data

  // { kind: "move" | "add", zone, index, type } while dragging, else null
  property var dragging: null
  // The lane under the pointer and the index the drop would insert at
  property string hoverZone: ""
  property int hoverIndex: -1

  property var _lanes: []

  readonly property string location: BarManager.selectedBar()?.location ?? "Top"
  readonly property bool vertical: root.location === "Left" || root.location === "Right"
  // The bar's sections in order. On a vertical bar they run top to
  // bottom; the keys stay the same.
  readonly property var zones: [
    {
      "key": "left",
      "label": root.vertical ? I18n.tr("Top") : I18n.tr("Left")
    },
    {
      "key": "leftCenter",
      "label": root.vertical ? I18n.tr("Top Center") : I18n.tr("Left Center")
    },
    {
      "key": "center",
      "label": I18n.tr("Center")
    },
    {
      "key": "rightCenter",
      "label": root.vertical ? I18n.tr("Bottom Center") : I18n.tr("Right Center")
    },
    {
      "key": "right",
      "label": root.vertical ? I18n.tr("Bottom") : I18n.tr("Right")
    }
  ]

  function zoneLabel(key) {
    return root.zones.find(z => z.key === key)?.label ?? key;
  }

  function typeInfo(type) {
    return Bar.availableWidgetTypes.find(t => t.type === type) ?? null;
  }

  // The type's label (its schema description), translated like titles
  function label(type) {
    const info = root.typeInfo(type);
    return info ? I18n.tr(info.label) : (type || I18n.tr("Unknown"));
  }

  // A short name for chips in the narrow section lanes: the type, spaced.
  // Keys: I18n.tr("Window") I18n.tr("Media") I18n.tr("Workspaces")
  // I18n.tr("Time") I18n.tr("Tailscale")
  // I18n.tr("Network") I18n.tr("System Tray") I18n.tr("Notifications")
  // I18n.tr("Button") I18n.tr("Battery") I18n.tr("System Stats")
  // I18n.tr("Keyboard Layout") I18n.tr("Idle Inhibitor") I18n.tr("Privacy")
  // I18n.tr("Updates") I18n.tr("Weather") I18n.tr("Separator")
  // I18n.tr("Volume") I18n.tr("Microphone") I18n.tr("Bluetooth")
  // I18n.tr("Screen Record")
  function shortLabel(type) {
    if (!type)
      return I18n.tr("Unknown");
    const spaced = type.replace(/([a-z])([A-Z])/g, "$1 $2");
    return I18n.tr(spaced);
  }

  // Material Symbols icon per widget type
  function icon(type) {
    switch (type) {
    case "Window":
      return "wrap_text";
    case "Media":
      return "music_note";
    case "Workspaces":
      return "grid_view";
    case "Time":
      return "schedule";
    case "Tailscale":
      return "vpn_lock";
    case "Network":
      return "wifi";
    case "SystemTray":
      return "apps";
    case "Notifications":
      return "notifications";
    case "Button":
      return "terminal";
    case "Battery":
      return "battery_full";
    case "SystemStats":
      return "memory_alt";
    case "KeyboardLayout":
      return "keyboard";
    case "IdleInhibitor":
      return "coffee";
    case "Privacy":
      return "visibility";
    case "ScreenRecord":
      return "radio_button_checked";
    case "Updates":
      return "package_2";
    case "Weather":
      return "partly_cloudy_day";
    case "Separator":
      return "more_vert";
    case "Volume":
      return "volume_up";
    case "Microphone":
      return "mic";
    case "Bluetooth":
      return "bluetooth";
    }
    return "settings";
  }

  function registerLane(lane) {
    root._lanes = root._lanes.concat([lane]);
  }

  function unregisterLane(lane) {
    root._lanes = root._lanes.filter(l => l !== lane);
  }

  // Starts carrying `payload`, picked up at (x, y) in `item` (the chip)
  function begin(payload, item, x, y) {
    ghost.type = payload.type;
    ghost.compact = item.compact;
    ghost.width = item.width;
    ghost.hotX = x;
    ghost.hotY = y;
    root.dragging = payload;
    root.move(item, x, y);
  }

  // The pointer is at (x, y) in `item`
  function move(item, x, y) {
    const p = item.mapToItem(root, x, y);
    ghost.x = p.x - ghost.hotX;
    ghost.y = p.y - ghost.hotY;
    let zone = "";
    let index = -1;
    for (const lane of root._lanes) {
      const q = root.mapToItem(lane, p.x, p.y);
      if (q.x >= 0 && q.y >= 0 && q.x < lane.width && q.y < lane.height) {
        zone = lane.zone;
        index = lane.indexAt(p);
        break;
      }
    }
    root.hoverZone = zone;
    root.hoverIndex = index;
  }

  // Dropped: moves or adds the widget where the pointer is, if over a lane
  function end() {
    const drag = root.dragging;
    const zone = root.hoverZone;
    const index = root.hoverIndex;
    root.cancel();
    if (!drag || zone === "")
      return;
    if (drag.kind === "move")
      BarManager.moveWidget(drag.zone, drag.index, zone, index);
    else
      BarManager.addWidget(zone, drag.type, index);
  }

  function cancel() {
    root.dragging = null;
    root.hoverZone = "";
    root.hoverIndex = -1;
  }

  Item {
    id: contentItem
    anchors.fill: parent
  }

  WidgetChip {
    id: ghost

    property real hotX: 0
    property real hotY: 0

    dragLayer: root
    visible: root.dragging !== null
    enabled: false
    selected: true
    z: 10
    opacity: 0.9
    scale: 1.04
  }
}
