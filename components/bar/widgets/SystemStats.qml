pragma ComponentBehavior: Bound
import QtQuick

import qs.services
import qs.config
import qs.components.reusable
import qs.components.hosts.popout

// CPU / memory / temperature / GPU / disk readouts from SystemManager, one
// icon + value segment per enabled metric. Metrics the machine can't report
// (no GPU, no CPU sensor) are left out.
BaseWidget {
  id: root

  property var barConfig
  property var popouts
  property var panel
  property var screen
  property var properties

  // Which segments show, from config and what the machine can report. A
  // string, so it only notifies when the set changes: a model rebuilt on
  // every sample would recreate the delegates many times a second.
  readonly property string segmentKeys: {
    const p = properties;
    const keys = [];
    if (p.showCpu)
      keys.push("cpu");
    if (p.showMemory)
      keys.push("mem");
    if (p.showTemp && SystemManager.hasCpuTemp)
      keys.push("temp");
    if (p.showGpu && SystemManager.hasGpu)
      keys.push("gpu");
    if (p.showDisk && SystemManager.disks[p.diskPath])
      keys.push("disk");
    return keys.join(",");
  }
  readonly property var segments: segmentKeys === "" ? [] : segmentKeys.split(",")

  // Live icon/value/level for one segment key
  function segmentData(key) {
    const p = properties;
    switch (key) {
    case "cpu":
      return {
        "icon": "memory",
        "value": `${SystemManager.cpuUsage}%`,
        "level": SystemManager.cpuUsage
      };
    case "mem":
      return {
        "icon": "memory_alt",
        "value": p.memoryFormat === "used" ? `${(SystemManager.memUsedBytes / 1073741824).toFixed(1)}G` : `${SystemManager.memUsage}%`,
        "level": SystemManager.memUsage
      };
    case "temp":
      return {
        "icon": "thermometer",
        "value": `${SystemManager.cpuTemp}°`,
        "level": SystemManager.cpuTemp
      };
    case "gpu":
      return {
        "icon": "developer_board",
        "value": `${SystemManager.gpuUsage}%`,
        "level": SystemManager.gpuUsage
      };
    default:
      {
        const usage = SystemManager.disks[p.diskPath]?.usage ?? 0;
        return {
          "icon": "hard_drive",
          "value": `${usage}%`,
          "level": usage
        };
      }
    }
  }
  readonly property bool warning: segments.some(key => segmentData(key).level >= properties.warnThreshold)
  readonly property color foregroundColor: Theme.resolveColor(properties.foregroundColor)

  isVertical: barConfig.vertical
  crossSize: barConfig.widgetSize
  padding: segments.length > 0 ? barConfig.widgetPadding : 0
  radius: barConfig.radius
  backgroundColor: Theme.resolveColor(warning ? properties.warnColor : properties.backgroundColor)

  // Ask only for what's shown; re-registering replaces the old request
  function register() {
    const p = properties;
    const metrics = [];
    if (p.showCpu)
      metrics.push("cpu");
    if (p.showMemory)
      metrics.push("mem");
    if (p.showTemp)
      metrics.push("cpuTemp");
    if (p.showGpu)
      metrics.push("gpu");
    if (p.showDisk)
      metrics.push("disk");
    SystemManager.acquire(root, {
      "interval": p.interval,
      "metrics": metrics,
      "diskPaths": p.showDisk ? [p.diskPath] : []
    });
  }
  onPropertiesChanged: register()
  Component.onCompleted: register()
  Component.onDestruction: SystemManager.release(root)

  // The popout graphs what the bar shows (disk has no history). From config
  // and what the machine can report only, as with segmentKeys
  readonly property var graphMetrics: {
    const p = properties;
    const metrics = [];
    if (p.showCpu)
      metrics.push("cpu");
    if (p.showMemory)
      metrics.push("mem");
    if (p.showTemp && SystemManager.hasCpuTemp)
      metrics.push("cpuTemp");
    if (p.showGpu && SystemManager.hasGpu)
      metrics.push("gpu");
    return metrics;
  }

  PopoutAnchor {
    popouts: root.popouts
    panel: root.panel
    popoutName: "SystemGraphs"
    active: root.properties.showPopout && root.graphMetrics.length > 0
    extraData: ({
        "popoutMetrics": root.graphMetrics
      })
  }

  content: Grid {
    columns: root.isVertical ? 1 : Math.max(1, root.segments.length)
    spacing: root.isVertical ? root.barConfig.widgetSpacing : root.barConfig.widgetPadding
    horizontalItemAlignment: Grid.AlignHCenter
    verticalItemAlignment: Grid.AlignVCenter

    Repeater {
      model: root.segments

      delegate: Grid {
        id: segment
        required property var modelData
        readonly property var stat: root.segmentData(modelData)

        columns: root.isVertical ? 1 : 2
        spacing: root.isVertical ? 0 : 4
        horizontalItemAlignment: Grid.AlignHCenter
        verticalItemAlignment: Grid.AlignVCenter

        StyledIcon {
          text: segment.stat.icon
          color: root.foregroundColor
          font.pixelSize: root.barConfig.fontSize
        }
        Text {
          text: segment.stat.value
          color: root.foregroundColor
          font.family: Appearance.fontFamily
          font.pixelSize: root.barConfig.fontSize * (root.isVertical ? 0.7 : 0.9)
        }
      }
    }
  }
}
