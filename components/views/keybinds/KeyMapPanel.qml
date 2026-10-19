pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import qs.config
import qs.services
import qs.components.methods
import qs.components.reusable

// The Keybinds editor's key map, shown while no bind is selected: a
// keyboard (KeyMap) under the modifiers picked, each key coloured by who
// holds it (KeyMap.occupancy). A free key starts a bind on it, an axiom
// key selects its bind.
ColumnLayout {
  id: root

  readonly property var occupancy: KeyMap.occupancy(KeybindManager.binds, KeybindManager.userKeyCounts, KeybindManager.keyMapMods)
  // One key unit, the main block being 15 wide
  readonly property real unit: (root.width - Widget.spacing / 2 * 14) / 15

  spacing: Widget.spacing * 1.5

  function pick(key) {
    const held = root.occupancy[key] ?? {
      "source": "free",
      "index": -1
    };
    if (held.index >= 0)
      KeybindManager.selectBind(held.index);
    else if (held.source === "free")
      KeybindManager.addBind({
        "key": KeyNames.join(KeybindManager.keyMapMods, key)
      });
  }

  function fill(source) {
    switch (source) {
    case "axiom":
      return Theme.accent;
    case "both":
      return Theme.error;
    case "paused":
      return Qt.alpha(Theme.accent, 0.3);
    case "user":
      return Qt.alpha(Theme.warning, 0.7);
    }
    return Theme.backgroundAlt;
  }

  SectionHeading {
    title: I18n.tr("Free keys")
    description: I18n.tr("Pick the modifiers to look under. Click a free key to bind it, or one of axiom's to edit its bind.")
  }

  Flow {
    Layout.fillWidth: true
    spacing: Widget.spacing / 2

    Repeater {
      model: KeyNames.modifiers

      delegate: SegmentButton {
        required property string modelData
        text: KeyNames.modifierLabel(modelData)
        active: KeybindManager.keyMapMods.includes(modelData)
        onClicked: KeybindManager.toggleKeyMapMod(modelData)
      }
    }
  }

  component KeyButton: Rectangle {
    id: keyButton

    required property var entry
    readonly property var held: root.occupancy[keyButton.entry.key] ?? {
      "source": "free",
      "index": -1
    }
    readonly property bool blank: keyButton.entry.key === ""
    readonly property bool clickable: !keyButton.blank && keyButton.held.source !== "user"

    implicitHeight: Math.round(Widget.height * 0.9)
    radius: Widget.radius / 2
    color: keyButton.blank ? "transparent" : root.fill(keyButton.held.source)
    border.width: keyArea.containsMouse && keyButton.clickable ? 1 : 0
    border.color: Theme.foreground

    StyledText {
      anchors.centerIn: parent
      width: parent.width - 4
      horizontalAlignment: Text.AlignHCenter
      text: keyButton.entry.label
      textColor: keyButton.held.source === "axiom" || keyButton.held.source === "both" ? Theme.background : Theme.foreground
      opacity: keyButton.blank ? 0.3 : 1
      textSize: Appearance.fontSize - 2
      elide: Text.ElideRight
    }

    MouseArea {
      id: keyArea
      anchors.fill: parent
      enabled: keyButton.clickable
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      onClicked: root.pick(keyButton.entry.key)
    }
  }

  ColumnLayout {
    Layout.fillWidth: true
    spacing: Widget.spacing / 2

    Repeater {
      model: KeyMap.rows

      delegate: Row {
        id: keyRow
        required property var modelData
        spacing: Widget.spacing / 2

        Repeater {
          model: keyRow.modelData

          delegate: KeyButton {
            required property var modelData
            entry: modelData
            width: root.unit * modelData.width + Widget.spacing / 2 * (modelData.width - 1)
          }
        }
      }
    }
  }

  Flow {
    Layout.fillWidth: true
    spacing: Widget.spacing / 2

    Repeater {
      model: KeyMap.extras

      delegate: KeyButton {
        required property var modelData
        entry: modelData
        width: root.unit * 1.6
      }
    }
  }

  // What the colours mean
  Flow {
    Layout.fillWidth: true
    spacing: Widget.spacing * 2

    Repeater {
      model: [["free", I18n.tr("Free")], ["axiom", I18n.tr("Axiom")], ["paused", I18n.tr("Paused")], ["user", I18n.tr("Your compositor config")], ["both", I18n.tr("Both")]]

      delegate: Row {
        id: legend
        required property var modelData
        spacing: Widget.spacing / 2

        Rectangle {
          anchors.verticalCenter: parent.verticalCenter
          width: Appearance.fontSize
          height: Appearance.fontSize
          radius: 3
          color: root.fill(legend.modelData[0])
          border.width: 1
          border.color: Theme.border
        }

        StyledText {
          text: legend.modelData[1]
          opacity: 0.7
          textSize: Appearance.fontSize - 2
        }
      }
    }
  }
}
