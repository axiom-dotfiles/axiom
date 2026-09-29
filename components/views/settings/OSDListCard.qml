pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.config
import qs.services
import qs.components.forms
import qs.components.methods
import qs.components.reusable

// The OSD section's first card (its `x-card`): the OSDs as tabs, one shown
// at a time: where it sits (a screen picker with presets), a Show button,
// and its settings and bars. Edits go through the settings draft like any
// other row (OSD.osds as one value), so they show live and wait for Save.
StyledContainer {
  id: root

  readonly property var entrySchema: ConfigManager.configSchema?.definitions?.OSDEntry ?? ({})
  readonly property var osds: SettingsManager.localConfig?.OSD?.osds ?? OSDConfig.osds
  property int selected: 0
  readonly property int current: Math.max(0, Math.min(root.selected, root.osds.length - 1))
  readonly property var osd: root.osds[root.current] ?? null

  // Places the picker offers: an edge's middle, or floating in the middle
  // or a third of the way up or down
  readonly property var presets: [
    {
      "label": "Top edge",
      "values": {
        "placement": "edge",
        "edge": "Top",
        "position": 50
      },
      "x": 0.5,
      "y": 0
    },
    {
      "label": "Bottom edge",
      "values": {
        "placement": "edge",
        "edge": "Bottom",
        "position": 50
      },
      "x": 0.5,
      "y": 1
    },
    {
      "label": "Left edge",
      "values": {
        "placement": "edge",
        "edge": "Left",
        "position": 50
      },
      "x": 0,
      "y": 0.5
    },
    {
      "label": "Right edge",
      "values": {
        "placement": "edge",
        "edge": "Right",
        "position": 50
      },
      "x": 1,
      "y": 0.5
    },
    {
      "label": "Centre",
      "values": {
        "placement": "floating",
        "x": 50,
        "y": 50
      },
      "x": 0.5,
      "y": 0.5
    },
    {
      "label": "Upper third",
      "values": {
        "placement": "floating",
        "x": 50,
        "y": 67
      },
      "x": 0.5,
      "y": 0.33
    },
    {
      "label": "Lower third",
      "values": {
        "placement": "floating",
        "x": 50,
        "y": 33
      },
      "x": 0.5,
      "y": 0.67
    }
  ]

  // Where the selected OSD sits, 0-1 from the top left of the screen
  readonly property point spot: {
    const osd = root.osd;
    if (!osd)
      return Qt.point(0.5, 0.5);
    if (osd.placement === "floating")
      return Qt.point(osd.x / 100, 1 - osd.y / 100);
    const along = osd.position / 100;
    switch (osd.edge) {
    case "Top":
      return Qt.point(along, 0);
    case "Left":
      return Qt.point(0, along);
    case "Right":
      return Qt.point(1, along);
    }
    return Qt.point(along, 1);
  }

  function _copy() {
    return JSON.parse(JSON.stringify(root.osds));
  }

  function _commit(osds) {
    SettingsManager.setValue(["OSD", "osds"], osds);
  }

  function edit(values) {
    const osds = root._copy();
    Object.assign(osds[root.current], values);
    root._commit(osds);
  }

  function _freeId(base) {
    const taken = root.osds.map(osd => osd.id);
    let id = base;
    for (let n = 2; taken.includes(id); n++)
      id = `${base}${n}`;
    return id;
  }

  function add() {
    const osds = root._copy();
    osds.push(SchemaValidation.applyDefaults({
      "id": root._freeId("osd"),
      "placement": "floating",
      "bars": [
        {
          "type": "brightness",
          "icon": "",
          "showOsd": true
        }
      ]
    }, root.entrySchema, ConfigManager.configSchema));
    root._commit(osds);
    root.selected = osds.length - 1;
  }

  function duplicate() {
    const osds = root._copy();
    const copy = JSON.parse(JSON.stringify(root.osd));
    copy.id = root._freeId(copy.id);
    osds.splice(root.current + 1, 0, copy);
    root._commit(osds);
    root.selected = root.current + 1;
  }

  function remove() {
    if (root.osds.length <= 1)
      return;
    const osds = root._copy();
    osds.splice(root.current, 1);
    root._commit(osds);
    root.selected = Math.min(root.current, osds.length - 1);
  }

  implicitHeight: column.implicitHeight + Widget.padding * 2
  backgroundColor: Theme.backgroundAlt

  ColumnLayout {
    id: column
    anchors.top: parent.top
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.margins: Widget.padding
    spacing: Widget.spacing * 1.5

    RowLayout {
      Layout.fillWidth: true
      spacing: Widget.spacing

      StyledText {
        text: I18n.tr("OSDs")
        textColor: Theme.accent
        textSize: Appearance.fontSize + 1
        font.bold: true
        Layout.fillWidth: true
      }

      StyledTextButton {
        implicitHeight: Widget.height - 4
        iconText: "add"
        text: I18n.tr("Add")
        onClicked: root.add()
      }
    }

    // One tab per OSD
    Flow {
      Layout.fillWidth: true
      spacing: Widget.spacing / 2

      Repeater {
        model: root.osds.length

        delegate: StyledTextButton {
          id: tab
          required property int index
          readonly property var osd: root.osds[index]
          readonly property bool isSelected: index === root.current

          implicitHeight: Widget.height - 4
          text: OSDConfig.labelOf(osd)
          opacity: osd.enabled ? 1 : 0.6
          backgroundColor: tab.isSelected ? Theme.accent : Theme.backgroundHighlight
          textColor: tab.isSelected ? Theme.background : Theme.foreground
          onClicked: root.selected = tab.index
        }
      }
    }

    RowLayout {
      visible: root.osd !== null
      Layout.fillWidth: true
      spacing: Widget.spacing * 2

      // The screen, with the selected OSD's spot and the presets to click
      Rectangle {
        id: screen
        readonly property real dot: 14

        Layout.preferredWidth: 192
        Layout.preferredHeight: 108
        Layout.alignment: Qt.AlignTop
        color: Theme.background
        border.color: Theme.border
        border.width: Appearance.borderWidth
        radius: Widget.radius / 2

        Repeater {
          model: root.presets

          delegate: Rectangle {
            id: preset
            required property var modelData
            readonly property bool hovered: presetArea.containsMouse

            width: screen.dot
            height: screen.dot
            radius: width / 2
            x: modelData.x * (screen.width - width)
            y: modelData.y * (screen.height - height)
            color: hovered ? Theme.accentAlt : Theme.backgroundHighlight
            border.color: Theme.border
            border.width: 1

            MouseArea {
              id: presetArea
              anchors.fill: parent
              anchors.margins: -4
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: root.edit(preset.modelData.values)
            }

            LazyLoader {
              active: preset.hovered
              StyledToolTip {
                target: preset
                // I18n.tr("Top edge") I18n.tr("Bottom edge") I18n.tr("Left edge") I18n.tr("Right edge") I18n.tr("Centre") I18n.tr("Upper third") I18n.tr("Lower third")
                text: I18n.tr(preset.modelData.label)
              }
            }
          }
        }

        // Where it is now
        Rectangle {
          width: screen.dot - 4
          height: screen.dot - 4
          radius: width / 2
          x: root.spot.x * (screen.width - screen.dot) + 2
          y: root.spot.y * (screen.height - screen.dot) + 2
          color: Theme.accent
        }
      }

      ColumnLayout {
        Layout.fillWidth: true
        Layout.alignment: Qt.AlignTop
        spacing: Widget.spacing

        StyledText {
          text: I18n.tr("Click a spot to place it; fine-tune below. Show opens it as a change would.")
          textColor: Theme.foregroundAlt
          textSize: Appearance.fontSize - 2
          wrapMode: Text.WordWrap
          Layout.fillWidth: true
        }

        Flow {
          Layout.fillWidth: true
          spacing: Widget.spacing / 2

          StyledTextButton {
            implicitHeight: Widget.height - 4
            iconText: "visibility"
            text: I18n.tr("Show")
            onClicked: ShellManager.showOsd(root.osd.id)
          }

          StyledTextButton {
            implicitHeight: Widget.height - 4
            iconText: "content_copy"
            text: I18n.tr("Duplicate")
            onClicked: root.duplicate()
          }

          StyledTextButton {
            visible: root.osds.length > 1
            implicitHeight: Widget.height - 4
            iconText: "delete"
            text: I18n.tr("Delete")
            hoverColor: Theme.error
            onClicked: root.remove()
          }
        }
      }
    }

    StyledSeparator {
      visible: root.osd !== null
      Layout.fillWidth: true
    }

    SchemaPropertiesForm {
      visible: root.osd !== null
      Layout.fillWidth: true
      propertiesSchema: root.entrySchema.properties ?? ({})
      order: root.entrySchema["x-order"] ?? []
      values: root.osd ?? ({})
      onEdited: (path, value) => root.edit({
          [path[0]]: value
        })
    }
  }
}
