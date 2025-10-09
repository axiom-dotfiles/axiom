pragma Singleton
import QtQuick

import Quickshell.Io

import qs.config
import qs.services

// TODO: better support
// much better support
QtObject {
  id: systemManager

  // -- Public --
  property real cpuUsage: 0.0
  property real cpuTemp: 0.0
  property real memUsage: 0.0
  property real memTemp: 0.0

  property var disks: []

  property real netDownload: 0.0
  property real netUpload: 0.0
  property string netInterface: "enp9s0"
  // property string netInterface: SystemManager.getDefaultNetworkInterface()

  property real gpuUsage: 0.0
  property real gpuTemp: 0.0
  property string gpu: "amd"

  function startMonitoring() {
    console.log("[SystemManager] Starting system monitoring");
    systemManager._startTimers();
    // Initial fetch
    if (!systemManager._getSystemStats.running) {
      systemManager._getSystemStats.running = true;
    }
    if (systemManager.gpu !== "none" && !systemManager._gpuStatsProcess.running) {
      systemManager._gpuStatsProcess.running = true;
    }
    if (!systemManager._disksProcess.running) {
      systemManager._disksProcess.running = true;
    }
  }

  function stopMonitoring() {
    console.log("[SystemManager] Stopping system monitoring");
    systemManager._stopTimers();
  }

  Component.onCompleted: {
    console.log("[SystemManager] Component completed, starting detection");
    systemManager.startMonitoring();
  }

  // -- Private --
  property var _rawCpuUsage: []
  property var _rawCpuTemp: []
  property var _rawMemUsage: []
  property var _rawNetUpload: []
  property var _rawNetDownload: []
  property var _rawGpuUsage: []
  property var _rawGpuTemp: []

  property var _pollingInterval: 3000
  property var _updateInterval: 1500
  property int _maxDataPoints: 5

  function _startTimers() {
    if (!systemManager._pollingTimer.running) {
      systemManager._pollingTimer.running = true;
    }
    if (!systemManager._updateTimer.running) {
      systemManager._updateTimer.running = true;
    }
    if (!systemManager._diskRefreshTimer.running) {
      systemManager._diskRefreshTimer.running = true;
    }
  }

  function _stopTimers() {
    if (systemManager._pollingTimer.running) {
      systemManager._pollingTimer.running = false;
    }
    if (systemManager._updateTimer.running) {
      systemManager._updateTimer.running = false;
    }
    if (systemManager._diskRefreshTimer.running) {
      systemManager._diskRefreshTimer.running = false;
    }
  }

  property Timer _pollingTimer: Timer {
    interval: systemManager._pollingInterval
    repeat: true
    running: true
    onTriggered: {
      if (!systemManager._getSystemStats.running) {
        systemManager._getSystemStats.running = true;
      }
      if (systemManager.gpu !== "none" && !systemManager._gpuStatsProcess.running) {
        systemManager._gpuStatsProcess.running = true;
      }
    }
  }

  property Timer _diskRefreshTimer: Timer {
    interval: 60000
    repeat: true
    running: true
    onTriggered: {
      systemManager._updateDisks();
    }
  }

  property Process _getSystemStats: Process {
    running: false
    command: [Config.scriptsPath + "get_system_stats.sh", systemManager.gpu]
    stdout: SplitParser {
      onRead: data => {
        data = data.trim();
        const stats = JSON.parse(data);
        if (stats.cpuUsage !== undefined) {
          systemManager._rawCpuUsage.push(stats.cpuUsage);
        }
        if (stats.cpuTemp !== undefined) {
          systemManager._rawCpuTemp.push(stats.cpuTemp);
        }
        if (stats.memUsage !== undefined) {
          systemManager._rawMemUsage.push(stats.memUsage);
        }
        if (stats.gpuUsage !== undefined) {
          systemManager._rawGpuUsage.push(stats.gpuUsage);
        }
        if (stats.gpuTemp !== undefined) {
          systemManager._rawGpuTemp.push(stats.gpuTemp);
        }
        if (stats.disks !== undefined) {
          systemManager.disks = stats.disks;
        }
      }
    }
    stderr: SplitParser {
      onRead: data => {
        console.error("[SystemManager] Error getting system stats:", data);
      }
    }
  }

  property Timer _updateTimer: Timer {
    interval: systemManager._updateInterval
    repeat: true
    running: true
    onTriggered: {
      if (!systemManager._getSystemStats.running) {
        systemManager._getSystemStats.running = true;
      }
      // Calculate rolling averages from raw data
      systemManager.cpuUsage = systemManager._calculateAverage(systemManager._rawCpuUsage);
      systemManager.cpuTemp = systemManager._calculateAverage(systemManager._rawCpuTemp);
      systemManager.memUsage = systemManager._calculateAverage(systemManager._rawMemUsage);
      systemManager.netUpload = systemManager._calculateAverage(systemManager._rawNetUpload);
      systemManager.netDownload = systemManager._calculateAverage(systemManager._rawNetDownload);
      systemManager.gpuUsage = systemManager._calculateAverage(systemManager._rawGpuUsage);
      systemManager.gpuTemp = systemManager._calculateAverage(systemManager._rawGpuTemp);

      // Trim arrays
      systemManager._trimArray(systemManager._rawCpuUsage, systemManager._maxDataPoints);
      systemManager._trimArray(systemManager._rawCpuTemp, systemManager._maxDataPoints);
      systemManager._trimArray(systemManager._rawMemUsage, systemManager._maxDataPoints);
      systemManager._trimArray(systemManager._rawNetUpload, systemManager._maxDataPoints);
      systemManager._trimArray(systemManager._rawNetDownload, systemManager._maxDataPoints);
      systemManager._trimArray(systemManager._rawGpuUsage, systemManager._maxDataPoints);
      systemManager._trimArray(systemManager._rawGpuTemp, systemManager._maxDataPoints);
    }
  }

  property Process _gpuStatsProcess: Process {
    running: false
    command: [Config.scriptsPath + "get_gpu_stats.sh", systemManager.gpu]
    stdout: SplitParser {
      onRead: data => {
        data = data.trim();
        const stats = JSON.parse(data);
        if (stats.gpuUsage !== undefined) {
          systemManager._rawGpuUsage.push(stats.gpuUsage);
        }
        if (stats.gpuTemp !== undefined) {
          systemManager._rawGpuTemp.push(stats.gpuTemp);
        }
      }
    }
    stderr: SplitParser {
      onRead: data => {
        console.error("[SystemManager] Error getting GPU stats:", data);
      }
    }
  }

  property Process _disksProcess: Process {
    running: false
    command: [Config.scriptsPath + "get_disks.sh"]
    stdout: SplitParser {
      onRead: data => {
        data = data.trim();
        const disks = JSON.parse(data);
        systemManager.disks = disks;
      }
    }
    stderr: SplitParser {
      onRead: data => {
        console.error("[SystemManager] Error getting disks:", data);
      }
    }
  }

  function _updateDisks() {
    if (!systemManager._disksProcess.running) {
      systemManager._disksProcess.running = true;
    }
  }

  function _calculateAverage(array) {
    if (array.length === 0)
      return 0;
    const sum = array.reduce((acc, val) => acc + val, 0);
    return sum / array.length;
  }

  function _trimArray(array, maxLength) {
    while (array.length > maxLength) {
      array.shift();
    }
  }
}
