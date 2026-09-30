pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.config
import qs.services
import qs.components.forms
import qs.components.methods
import qs.components.reusable

// The Dock section's first card (its `x-card`): the docks as tabs, one
// shown at a time: where it sits (a screen picker with presets), Show, its
// pinned apps (with a search to add more) and its settings. Edits go
// through the settings draft like any other row (Dock.docks as one value),
// so they show live and wait for Save.
StyledContainer {
  id: root

  readonly property var entrySchema: ConfigManager.configSchema?.definitions?.DockEntry ?? ({})
  readonly property var docks: SettingsManager.localConfig?.Dock?.docks ?? DockConfig.docks
  property int selected: 0
  // Folded by clicking the header, like the generated cards (their key)
  // The settings group key it folds under, from SettingsContent
  property string foldKey
  readonly property bool collapsed: SettingsManager.isCollapsed(root.foldKey)
  readonly property int current: Math.max(0, Math.min(root.selected, root.docks.length - 1))
  readonly property var dock: root.docks[root.current] ?? null
  readonly property var pinned: root.dock?.pinned ?? []

  // An edge's middle, or its ends
  readonly property var presets: [
    {
      "label": "Bottom",
      "values": {
        "edge": "Bottom",
        "position": 50
      },
      "x": 0.5,
      "y": 1
    },
    {
      "label": "Bottom left",
      "values": {
        "edge": "Bottom",
        "position": 0
      },
      "x": 0.08,
      "y": 1
    },
    {
      "label": "Bottom right",
      "values": {
        "edge": "Bottom",
        "position": 100
      },
      "x": 0.92,
      "y": 1
    },
    {
      "label": "Top",
      "values": {
        "edge": "Top",
        "position": 50
      },
      "x": 0.5,
      "y": 0
    },
    {
      "label": "Left",
      "values": {
        "edge": "Left",
        "position": 50
      },
      "x": 0,
      "y": 0.5
    },
    {
      "label": "Right",
      "values": {
        "edge": "Right",
        "position": 50
      },
      "x": 1,
      "y": 0.5
    }
  ]

  // Where the selected dock sits, 0-1 from the top left of the screen
  readonly property point spot: {
    const dock = root.dock;
    if (!dock)
      return Qt.point(0.5, 1);
    const along = dock.position / 100;
    switch (dock.edge) {
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
    return JSON.parse(JSON.stringify(root.docks));
  }

  function _commit(docks) {
    SettingsManager.setValue(["Dock", "docks"], docks);
  }

  function edit(values) {
    const docks = root._copy();
    Object.assign(docks[root.current], values);
    root._commit(docks);
  }

  function _freeId(base) {
    return Utils.freeId(base, root.docks.map(dock => dock.id));
  }

  function add() {
    const docks = root._copy();
    docks.push(SchemaValidation.applyDefaults({
      "id": root._freeId("dock")
    }, root.entrySchema, ConfigManager.configSchema));
    root._commit(docks);
    root.selected = docks.length - 1;
  }

  function duplicate() {
    const docks = root._copy();
    const copy = JSON.parse(JSON.stringify(root.dock));
    copy.id = root._freeId(copy.id);
    docks.splice(root.current + 1, 0, copy);
    root._commit(docks);
    root.selected = root.current + 1;
  }

  function remove() {
    if (root.docks.length <= 1)
      return;
    const docks = root._copy();
    docks.splice(root.current, 1);
    root._commit(docks);
    root.selected = Math.min(root.current, docks.length - 1);
  }

  function pinApp(id) {
    if (!root.pinned.includes(id))
      root.edit({
        "pinned": root.pinned.concat([id])
      });
  }

  function unpinAt(index) {
    root.edit({
      "pinned": root.pinned.filter((_, i) => i !== index)
    });
  }

  function movePinned(index, by) {
    const to = index + by;
    if (to < 0 || to >= root.pinned.length)
      return;
    const pinned = root.pinned.slice();
    pinned.splice(to, 0, pinned.splice(index, 1)[0]);
    root.edit({
      "pinned": pinned
    });
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

    // Header: the title folds the card (as the generated cards do)
    RowLayout {
      Layout.fillWidth: true
      spacing: Widget.spacing

      Item {
        Layout.fillWidth: true
        implicitHeight: titleRow.implicitHeight

        MouseArea {
          id: headerArea
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: SettingsManager.setCollapsed(root.foldKey, !root.collapsed)
        }

        RowLayout {
          id: titleRow
          anchors.left: parent.left
          anchors.right: parent.right
          spacing: Widget.spacing

          StyledText {
            text: I18n.tr("Docks")
            textColor: Theme.accent
            textSize: Appearance.fontSize + 1
            font.bold: true
            Layout.fillWidth: true
          }

          StyledIcon {
            text: "expand_more"
            textColor: headerArea.containsMouse ? Theme.accent : Theme.foregroundAlt
            textSize: Appearance.fontSize + 4
            rotation: root.collapsed ? -90 : 0

            Behavior on rotation {
              NumberAnimation {
                duration: Appearance.animNormal
                easing.type: Easing.OutCubic
              }
            }
          }
        }
      }

      StyledTextButton {
        visible: !root.collapsed
        implicitHeight: Widget.height - 4
        iconText: "add"
        text: I18n.tr("Add")
        onClicked: root.add()
      }
    }

    // The rest, clipped while folding
    Item {
      id: body
      property real shown: root.collapsed ? 0 : 1
      Layout.fillWidth: true
      Layout.preferredHeight: bodyColumn.implicitHeight * shown
      visible: shown > 0
      clip: shown < 1

      Behavior on shown {
        NumberAnimation {
          duration: Appearance.animNormal
          easing.type: Easing.OutCubic
        }
      }

      ColumnLayout {
        id: bodyColumn
        anchors.left: parent.left
        anchors.right: parent.right
        spacing: Widget.spacing * 1.5

        StyledText {
          visible: !(SettingsManager.localConfig?.Dock?.enabled ?? DockConfig.enabled)
          text: I18n.tr("Docks are off: turn on Enabled below to show them.")
          textColor: Theme.foregroundAlt
          textSize: Appearance.fontSize - 2
          wrapMode: Text.WordWrap
          Layout.fillWidth: true
        }

        // One tab per dock
        Flow {
          Layout.fillWidth: true
          spacing: Widget.spacing / 2

          Repeater {
            model: root.docks.length

            delegate: StyledTextButton {
              id: tab
              required property int index
              readonly property var dock: root.docks[index]
              readonly property bool isSelected: index === root.current

              implicitHeight: Widget.height - 4
              text: DockConfig.labelOf(dock)
              opacity: dock.enabled ? 1 : 0.6
              backgroundColor: tab.isSelected ? Theme.accent : Theme.backgroundHighlight
              textColor: tab.isSelected ? Theme.background : Theme.foreground
              onClicked: root.selected = tab.index
            }
          }
        }

        RowLayout {
          visible: root.dock !== null
          Layout.fillWidth: true
          spacing: Widget.spacing * 2

          // The screen, with the selected dock's spot and the presets to click
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
                    // I18n.tr("Bottom") I18n.tr("Bottom left") I18n.tr("Bottom right") I18n.tr("Top") I18n.tr("Left") I18n.tr("Right")
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
              text: I18n.tr("Click a spot to place it; fine-tune below. Show slides a hidden dock in.")
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
                onClicked: DockManager.show(root.dock.id)
              }

              StyledTextButton {
                implicitHeight: Widget.height - 4
                iconText: "content_copy"
                text: I18n.tr("Duplicate")
                onClicked: root.duplicate()
              }

              StyledTextButton {
                visible: root.docks.length > 1
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
          separatorColor: Theme.accent
          visible: root.dock !== null
          Layout.fillWidth: true
        }

        // --- Pinned apps ---
        StyledText {
          visible: root.dock !== null
          text: I18n.tr("Pinned apps")
          font.bold: true
          Layout.fillWidth: true
        }

        StyledText {
          visible: root.dock !== null && root.pinned.length === 0
          text: I18n.tr("None yet: search below, or right-click a running app on the dock and pick Keep in dock.")
          textColor: Theme.foregroundAlt
          textSize: Appearance.fontSize - 2
          wrapMode: Text.WordWrap
          Layout.fillWidth: true
        }

        Repeater {
          model: root.dock ? root.pinned.length : 0

          delegate: AppRow {
            id: pinnedRow
            required property int index
            readonly property string appId: root.pinned[index]
            readonly property var entry: DockManager.entryFor(appId)

            Layout.fillWidth: true
            iconSource: DockManager.iconFor(appId, null)
            name: entry?.name || appId
            detail: entry ? "" : I18n.tr("No app with this id")

            StyledIconButton {
              iconText: "arrow_upward"
              tooltipText: I18n.tr("Move up")
              enabled: pinnedRow.index > 0
              Layout.fillWidth: false
              Layout.preferredWidth: Widget.height - 4
              Layout.preferredHeight: Widget.height - 4
              onClicked: root.movePinned(pinnedRow.index, -1)
            }

            StyledIconButton {
              iconText: "arrow_downward"
              tooltipText: I18n.tr("Move down")
              enabled: pinnedRow.index < root.pinned.length - 1
              Layout.fillWidth: false
              Layout.preferredWidth: Widget.height - 4
              Layout.preferredHeight: Widget.height - 4
              onClicked: root.movePinned(pinnedRow.index, 1)
            }

            StyledIconButton {
              iconText: "close"
              tooltipText: I18n.tr("Remove")
              hoverColor: Theme.error
              Layout.fillWidth: false
              Layout.preferredWidth: Widget.height - 4
              Layout.preferredHeight: Widget.height - 4
              onClicked: root.unpinAt(pinnedRow.index)
            }
          }
        }

        StyledTextEntry {
          id: search
          visible: root.dock !== null
          placeholderText: I18n.tr("Search apps to pin…")
          Layout.fillWidth: true
          Layout.preferredHeight: Widget.height
        }

        // The best matches not pinned yet (the most used ones before anything
        // is typed); click one to pin it
        Flow {
          visible: root.dock !== null
          Layout.fillWidth: true
          spacing: Widget.spacing / 2

          Repeater {
            model: root.dock ? LauncherManager.searchApps(search.text, 24).filter(app => !root.pinned.includes(app.id)).slice(0, 8) : []

            delegate: StyledTextButton {
              id: result
              required property var modelData
              implicitHeight: Widget.height - 4
              iconText: "add"
              text: result.modelData.name
              onClicked: {
                root.pinApp(result.modelData.id);
                search.text = "";
              }
            }
          }
        }

        StyledSeparator {
          separatorColor: Theme.accent
          visible: root.dock !== null
          Layout.fillWidth: true
        }

        SchemaPropertiesForm {
          visible: root.dock !== null
          Layout.fillWidth: true
          propertiesSchema: root.entrySchema.properties ?? ({})
          order: root.entrySchema["x-order"] ?? []
          values: root.dock ?? ({})
          onEdited: (path, value) => root.edit({
              [path[0]]: value
            })
        }
      }
    }
  }

  // A pinned app: its icon and name, then the buttons given as children
  component AppRow: RowLayout {
    id: row
    property string iconSource: ""
    property string name: ""
    property string detail: ""
    default property alias buttons: extra.data

    spacing: Widget.spacing

    Image {
      Layout.preferredWidth: Widget.height - 8
      Layout.preferredHeight: Widget.height - 8
      sourceSize: Qt.size(64, 64)
      source: row.iconSource
      asynchronous: true
    }

    StyledText {
      text: row.name
      elide: Text.ElideRight
      Layout.fillWidth: true
    }

    StyledText {
      visible: row.detail !== ""
      text: row.detail
      textColor: Theme.error
      textSize: Appearance.fontSize - 2
    }

    RowLayout {
      id: extra
      spacing: 2
    }
  }
}
