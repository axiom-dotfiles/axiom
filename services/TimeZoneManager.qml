pragma Singleton
pragma ComponentBehavior: Bound
import QtQuick
import Quickshell.Io
import qs.components.methods

// Other time zones' UTC offsets, for clocks set to one (a Clock module's
// or a bar Time widget's `timezone`): the JS engine can't convert times
// between zones (TimeZones). Each zone asked for is read once for all its
// clocks (`date +%z` with TZ set), again past every half hour (when
// daylight saving changes), and not at all with none asked for. The zone
// travels as an argument, never inside the shell text.
//   TimeZoneManager.acquire(owner, "Asia/Tokyo")   // "" releases
//   TimeZoneManager.offsetOf("Asia/Tokyo")          // 540, null until read
// Also lists the system's zones (`zones`), for the time zone fields.
QtObject {
  id: root

  // zone -> minutes east of UTC
  readonly property var offsets: root._offsets
  property var _offsets: ({})
  // The system's zone names, sorted ([] until read)
  readonly property var zones: root._zones
  property var _zones: []

  function acquire(owner, zone) {
    if (!zone) {
      root.release(owner);
      return;
    }
    root._registry.acquire(owner, {
      "zone": zone
    });
  }

  function release(owner) {
    root._registry.release(owner);
  }

  // A zone's offset, or null (its clock shows the system's time): not read
  // yet, or not one of the system's zones (for which `date` would quietly
  // give UTC)
  function offsetOf(zone) {
    if (!zone || (root._zones.length > 0 && !root._zones.includes(zone)))
      return null;
    return root._offsets[zone] ?? null;
  }

  // -- Private --
  property ConsumerRegistry _registry: ConsumerRegistry {}
  // The zones asked for, as a key: identical requests don't re-read
  readonly property string _wanted: root._registry.requests.map(request => request.zone).filter((zone, i, all) => all.indexOf(zone) === i).sort().join("\n")
  on_WantedChanged: root._read()
  // Asked again while reading: read once more after
  property bool _again: false
  // The zones being read, in the order `date` answers
  property var _reading: []

  function _read() {
    if (root._wanted === "") {
      root._timer.stop();
      return;
    }
    if (root._reader.running) {
      root._again = true;
      return;
    }
    const zones = root._wanted.split("\n");
    root._reading = zones;
    root._reader.command = ["sh", "-c", 'for zone do TZ="$zone" date +%z; done', "sh"].concat(zones);
    root._reader.running = true;
  }

  property Process _reader: Process {
    stdout: StdioCollector {
      onStreamFinished: {
        const lines = text.split("\n");
        const offsets = Object.assign({}, root._offsets);
        root._reading.forEach((zone, i) => {
          const offset = TimeZones.parseOffset(lines[i]);
          if (offset !== null)
            offsets[zone] = offset;
        });
        if (JSON.stringify(offsets) !== JSON.stringify(root._offsets))
          root._offsets = offsets;
      }
    }
    onExited: {
      if (root._again) {
        root._again = false;
        root._read();
        return;
      }
      root._timer.interval = TimeZones.msToNextCheck(new Date());
      root._timer.restart();
    }
  }

  property Timer _timer: Timer {
    repeat: false
    onTriggered: root._read()
  }

  property Process _lister: Process {
    running: true
    command: ["sh", "-c", `{ awk '$1 == "Z" { print $2 } $1 == "L" { print $3 }' /usr/share/zoneinfo/tzdata.zi 2>/dev/null || timedatectl list-timezones; } | sort -u`]
    stdout: StdioCollector {
      onStreamFinished: root._zones = text.split("\n").filter(zone => zone !== "")
    }
  }
}
