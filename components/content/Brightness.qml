pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts

import qs.services
import qs.config
import qs.components.reusable
import qs.components.content.parts
import qs.components.content.base

// Screen brightness (BrightnessManager: a laptop panel's backlight, an
// external monitor over DDC/CI). On one monitor, its slider; on all of
// them, one slider setting every monitor (showing their mean), and below
// it, where there's room, a slider per monitor. A strip is the one
// slider, opening the full card over the grid; compact, the level.
// Changes here don't open the OSD.
// properties: { monitor: "*" (all) | "" (the primary monitor) | a name }
Panel {
  id: root

  readonly property bool all: root.properties.monitor === "*"
  readonly property string monitorName: root.properties.monitor || General.primaryMonitor
  // The monitors it sets, those with a controller
  readonly property var targets: root.all ? BrightnessManager.names : BrightnessManager.names.filter(name => name === root.monitorName)
  readonly property real level: BrightnessManager.average(root.targets)
  // All, with more than one: a row per monitor under the shared one
  readonly property bool perMonitor: root.all && root.targets.length > 1
  // A short card: the shared slider alone
  readonly property bool sliderOnly: root.embedded && root.height < Appearance.fontSize * 9

  fullMinWidth: Appearance.fontSize * 12
  fullMinHeight: Appearance.fontSize * 3.5

  function icon(level) {
    return level < 0.34 ? "brightness_low" : level < 0.67 ? "brightness_medium" : "brightness_high";
  }

  // Values changed outside axiom
  Component.onCompleted: root.targets.forEach(name => BrightnessManager.refresh(name))

  compactContent: CompactFigure {
    icon: root.icon(root.level)
    value: root.targets.length > 0 ? String(Math.round(root.level * 100)) : ""
    unit: root.targets.length > 0 ? "%" : ""
    label: root.targets.length > 0 ? I18n.tr("Brightness") : I18n.tr("No control")
  }

  ModuleHeader {
    visible: !root.sliderOnly
    icon: root.icon(root.level)
    title: I18n.tr("Brightness")
  }

  // Nothing to control here
  Item {
    visible: root.targets.length === 0
    Layout.fillWidth: true
    Layout.fillHeight: true
    EmptyState {
      anchors.centerIn: parent
      maxWidth: parent.width
      availableHeight: parent.height
      icon: "brightness_empty"
      text: I18n.tr("No monitor here has a brightness control (brightnessctl or ddcutil)")
    }
  }

  // Every target at once (the one monitor, or all)
  RowLayout {
    visible: root.targets.length > 0
    Layout.fillWidth: true
    Layout.alignment: root.sliderOnly ? Qt.AlignVCenter : Qt.AlignTop
    spacing: 0

    AudioRow {
      icon: root.icon(root.level)
      title: root.all ? I18n.tr("All monitors") : root.monitorName
      volume: root.level
      showMute: false
      onVolumeMoved: v => BrightnessManager.setMany(root.targets, v, true)
    }

    ExpandButton {
      module: root
      type: root.sliderOnly && root.perMonitor ? "Brightness" : ""
      properties: root.properties
    }
  }

  StyledSeparator {
    visible: root.perMonitor && !root.sliderOnly
    Layout.fillWidth: true
    separatorColor: Theme.backgroundHighlight
  }

  // A row per monitor (modelled by count: BrightnessManager.names only
  // changes when a monitor comes or goes)
  StyledScrollView {
    id: scroll
    visible: root.perMonitor && !root.sliderOnly
    Layout.fillWidth: true
    Layout.fillHeight: true
    contentPadding: 0
    showScrollBar: list.implicitHeight > scroll.height

    ColumnLayout {
      id: list
      width: scroll.availableWidth
      spacing: 2

      Repeater {
        model: root.perMonitor ? root.targets.length : 0

        AudioRow {
          required property int index
          readonly property string name: root.targets[index] ?? ""
          readonly property real value: BrightnessManager.valueFor(name)
          icon: root.icon(value)
          title: name
          volume: value
          showMute: false
          onVolumeMoved: v => BrightnessManager.set(name, v, true)
        }
      }
    }
  }

  Item {
    visible: root.targets.length > 0 && !root.perMonitor && !root.sliderOnly
    Layout.fillHeight: true
  }
}
