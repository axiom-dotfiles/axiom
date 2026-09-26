pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// CPU / memory / temperature / GPU / disk usage, polled only while something
// is showing it. Consumers register what they need with acquire(owner,
// {interval, metrics, diskPaths}) and drop it with release(owner); the
// service reads the union of requested metrics at the fastest requested
// interval, and stops entirely when nothing is registered.
//
// Everything on the hot path is a sysfs / procfs read through FileView, so
// polling never spawns a process. The exceptions are disk usage (`df`, on
// its own slow timer) and NVIDIA GPUs (`nvidia-smi`, only without an AMD
// card). Metric names: "cpu", "mem", "cpuTemp", "gpu", "disk", "net"
// (throughput from /proc/net/dev; the connection itself is
// NetworkingManager's) and "processes" (`top`, two frames so %CPU is
// current).
// Request `history: true` to also keep the last `historyLength` samples of
// each polled metric (for graphs).
QtObject {
  id: root

  // -- Public --
  property real cpuUsage: 0
  property real cpuTemp: 0
  property real memUsage: 0
  property real memUsedBytes: 0
  property real memTotalBytes: 0
  property real gpuUsage: 0
  property real gpuTemp: 0
  // Mount path -> { used, total, usage } for every requested disk path
  property var disks: ({})
  // Bytes per second, summed over every interface but loopback
  property real netRx: 0
  property real netTx: 0
  // [{ pid, user, cpu, mem, command }], every process, by CPU (descending)
  property var processes: []

  // Oldest first, `historyLength` samples at most (only kept on request)
  readonly property int historyLength: 60
  property var cpuHistory: []
  property var memHistory: []
  property var gpuHistory: []
  property var cpuTempHistory: []
  property var netRxHistory: []
  property var netTxHistory: []

  // What this machine can report, known once discovery has run
  readonly property bool hasCpuTemp: _cpuTempPath !== ""
  readonly property bool hasGpu: _gpuBusyPath !== "" || _hasNvidia

  function acquire(owner, request) {
    _registry.acquire(owner, {
      "interval": request?.interval ?? 2000,
      "metrics": request?.metrics ?? [],
      "diskPaths": request?.diskPaths ?? [],
      "history": request?.history ?? false
    });
  }

  function release(owner) {
    _registry.release(owner);
  }

  function wants(metric) {
    return root._metrics.includes(metric);
  }

  function kill(pid) {
    Quickshell.execDetached(["kill", String(pid)]);
    Qt.callLater(root._poll);
  }

  // -- Private --
  property ConsumerRegistry _registry: ConsumerRegistry {}
  readonly property var _requests: _registry.requests

  readonly property bool _active: _registry.active
  // (the QML JS engine has no Array.flatMap)
  readonly property var _metrics: [...new Set([].concat(..._requests.map(r => r.metrics)))]
  readonly property var _diskPaths: [...new Set([].concat(..._requests.map(r => r.diskPaths)))]
  readonly property bool _history: _requests.some(r => r.history)
  readonly property int _interval: _requests.length > 0 ? Math.max(500, Math.min(..._requests.map(r => r.interval))) : 2000

  // Found by _discover; empty when this machine has no such sensor
  property string _cpuTempPath: ""
  property string _gpuBusyPath: ""
  property string _gpuTempPath: ""
  property bool _hasNvidia: false
  property bool _discovered: false

  // Previous /proc/stat totals, for the usage delta
  property real _lastCpuTotal: 0
  property real _lastCpuIdle: 0
  // Previous /proc/net/dev totals and when they were read
  property real _lastRx: -1
  property real _lastTx: -1
  property real _lastNetTime: 0

  // Samples the current values into the histories (one tick behind the
  // reads, which land asynchronously)
  function _record() {
    if (!_history)
      return;
    const push = (list, value) => {
      const next = list.concat([value]);
      return next.length > historyLength ? next.slice(next.length - historyLength) : next;
    };
    if (wants("cpu"))
      cpuHistory = push(cpuHistory, cpuUsage);
    if (wants("mem"))
      memHistory = push(memHistory, memUsage);
    if (wants("gpu"))
      gpuHistory = push(gpuHistory, gpuUsage);
    if (wants("cpuTemp"))
      cpuTempHistory = push(cpuTempHistory, cpuTemp);
    if (wants("net")) {
      netRxHistory = push(netRxHistory, netRx);
      netTxHistory = push(netTxHistory, netTx);
    }
  }

  function _poll() {
    _record();
    if (wants("net"))
      _netDev.reload();
    if (wants("processes") && !_top.running)
      _top.running = true;
    if (wants("cpu"))
      _stat.reload();
    if (wants("mem"))
      _meminfo.reload();
    if (wants("cpuTemp") && _cpuTempPath)
      _cpuTempFile.reload();
    if (wants("gpu")) {
      if (_gpuBusyPath) {
        _gpuBusyFile.reload();
        if (_gpuTempPath)
          _gpuTempFile.reload();
      } else if (_hasNvidia && !_nvidia.running) {
        _nvidia.running = true;
      }
    }
  }

  function _pollDisks() {
    if (wants("disk") && _diskPaths.length > 0 && !_df.running) {
      _df.command = ["df", "-B1", "--output=used,size", ..._diskPaths];
      _df.running = true;
    }
  }

  function _parseStat(text) {
    // cpu  user nice system idle iowait irq softirq steal ...
    const fields = text.split("\n")[0].trim().split(/\s+/).slice(1).map(Number);
    const idle = fields[3] + (fields[4] || 0);
    const total = fields.slice(0, 8).reduce((sum, v) => sum + (v || 0), 0);
    const dTotal = total - _lastCpuTotal;
    if (_lastCpuTotal > 0 && dTotal > 0)
      cpuUsage = Math.round((1 - (idle - _lastCpuIdle) / dTotal) * 100);
    _lastCpuTotal = total;
    _lastCpuIdle = idle;
  }

  function _parseNetDev(text) {
    let rx = 0, tx = 0;
    text.split("\n").slice(2).forEach(line => {
      const [name, rest] = line.split(":");
      if (!rest || name.trim() === "lo")
        return;
      const fields = rest.trim().split(/\s+/).map(Number);
      rx += fields[0] || 0;
      tx += fields[8] || 0;
    });
    const now = Date.now();
    if (_lastRx >= 0 && now > _lastNetTime) {
      const secs = (now - _lastNetTime) / 1000;
      netRx = Math.max(0, (rx - _lastRx) / secs);
      netTx = Math.max(0, (tx - _lastTx) / secs);
    }
    _lastRx = rx;
    _lastTx = tx;
    _lastNetTime = now;
  }

  function _parseTop(text) {
    // Only the second frame: the first averages over each process' life
    const frames = text.split(/^top - /m);
    const lines = (frames[frames.length - 1] ?? "").split("\n");
    const header = lines.findIndex(l => /^\s*PID\s/.test(l));
    if (header < 0)
      return;
    processes = lines.slice(header + 1).filter(l => l.trim() !== "").map(l => {
      const f = l.trim().split(/\s+/);
      return {
        "pid": Number(f[0]),
        "user": f[1],
        "cpu": Number(f[8]) || 0,
        "mem": Number(f[9]) || 0,
        "command": f.slice(11).join(" ")
      };
    }).filter(p => p.pid > 0 && !p.command.startsWith("top"));
  }

  function _parseMeminfo(text) {
    const kb = key => Number((text.match(new RegExp("^" + key + ":\\s+(\\d+)", "m")) || [])[1] || 0);
    const total = kb("MemTotal");
    const available = kb("MemAvailable");
    if (total > 0) {
      memTotalBytes = total * 1024;
      memUsedBytes = (total - available) * 1024;
      memUsage = Math.round((total - available) / total * 100);
    }
  }

  // Reset the CPU delta when polling restarts, so the first sample after a
  // pause isn't averaged over the whole pause
  on_ActiveChanged: {
    if (!_active) {
      _lastCpuTotal = 0;
      _lastCpuIdle = 0;
      _lastRx = -1;
    } else {
      Qt.callLater(root._poll);
      Qt.callLater(root._pollDisks);
    }
  }
  on_DiskPathsChanged: Qt.callLater(root._pollDisks)

  property Timer _timer: Timer {
    interval: root._interval
    repeat: true
    running: root._active && root._discovered
    triggeredOnStart: true
    onTriggered: root._poll()
  }

  property Timer _diskTimer: Timer {
    interval: 60000
    repeat: true
    running: root._active && root.wants("disk")
    onTriggered: root._pollDisks()
  }

  property FileView _netDev: FileView {
    path: "/proc/net/dev"
    onLoaded: root._parseNetDev(text())
  }

  property Process _top: Process {
    command: ["top", "-b", "-n", "2", "-d", "0.5", "-w", "512", "-o", "%CPU"]
    stdout: StdioCollector {
      onStreamFinished: root._parseTop(text)
    }
  }

  property FileView _stat: FileView {
    path: "/proc/stat"
    onLoaded: root._parseStat(text())
  }

  property FileView _meminfo: FileView {
    path: "/proc/meminfo"
    onLoaded: root._parseMeminfo(text())
  }

  property FileView _cpuTempFile: FileView {
    path: root._cpuTempPath
    onLoaded: root.cpuTemp = Math.round(Number(text()) / 1000)
  }

  property FileView _gpuBusyFile: FileView {
    path: root._gpuBusyPath
    onLoaded: root.gpuUsage = Number(text()) || 0
  }

  property FileView _gpuTempFile: FileView {
    path: root._gpuTempPath
    onLoaded: root.gpuTemp = Math.round(Number(text()) / 1000)
  }

  property Process _nvidia: Process {
    command: ["nvidia-smi", "--query-gpu=utilization.gpu,temperature.gpu", "--format=csv,noheader,nounits"]
    stdout: StdioCollector {
      onStreamFinished: {
        const [usage, temp] = text.split("\n")[0].split(",").map(v => Number(v.trim()));
        root.gpuUsage = usage || 0;
        root.gpuTemp = temp || 0;
      }
    }
  }

  property Process _df: Process {
    stdout: StdioCollector {
      onStreamFinished: {
        // Header line, then one "used size" line per requested path, in order
        const lines = text.trim().split("\n").slice(1);
        const paths = root._df.command.slice(3);
        const disks = {};
        lines.forEach((line, i) => {
          const [used, total] = line.trim().split(/\s+/).map(Number);
          if (paths[i] && total > 0)
            disks[paths[i]] = {
              "used": used,
              "total": total,
              "usage": Math.round(used / total * 100)
            };
        });
        root.disks = disks;
      }
    }
  }

  // One-off sensor discovery: the CPU package sensor, and the AMD card with
  // the most VRAM (the discrete one, when there's also an iGPU)
  property Process _discover: Process {
    running: true
    command: ["sh", "-c", `
      for h in /sys/class/hwmon/hwmon*; do
        case "$(cat "$h/name" 2>/dev/null)" in
          k10temp|coretemp|zenpower) echo "cpuTemp $h/temp1_input"; break ;;
        esac
      done
      best=-1
      for d in /sys/class/drm/card*/device; do
        [ -r "$d/gpu_busy_percent" ] || continue
        vram=$(cat "$d/mem_info_vram_total" 2>/dev/null || echo 0)
        if [ "$vram" -gt "$best" ]; then best=$vram; card=$d; fi
      done
      if [ -n "$card" ]; then
        echo "gpu $card/gpu_busy_percent"
        t=$(ls "$card"/hwmon/*/temp1_input 2>/dev/null | head -n1)
        [ -n "$t" ] && echo "gpuTemp $t"
      fi
      command -v nvidia-smi >/dev/null 2>&1 && echo "nvidia 1"
      true
    `]
    stdout: StdioCollector {
      onStreamFinished: {
        for (const line of text.trim().split("\n")) {
          const [key, value] = line.split(" ");
          if (key === "cpuTemp")
            root._cpuTempPath = value;
          else if (key === "gpu")
            root._gpuBusyPath = value;
          else if (key === "gpuTemp")
            root._gpuTempPath = value;
          else if (key === "nvidia")
            root._hasNvidia = true;
        }
        root._discovered = true;
      }
    }
  }
}
