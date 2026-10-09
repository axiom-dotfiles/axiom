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
//   TimeZoneManager.acquire(owner, ["Asia/Tokyo", "Europe/Paris"])
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

  // One zone, or a list (World clocks); none releases
  function acquire(owner, zone) {
    const zones = (Array.isArray(zone) ? zone : [zone]).filter(z => !!z).filter((z, i, all) => all.indexOf(z) === i).sort();
    if (zones.length === 0) {
      root.release(owner);
      return;
    }
    root._registry.acquire(owner, {
      "zones": zones
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
  readonly property string _wanted: [].concat(...root._registry.requests.map(request => request.zones)).filter((zone, i, all) => all.indexOf(zone) === i).sort().join("\n")
  on_WantedChanged: root._read()
  // Asked again while reading: read once more after
  property bool _again: false

  function _read() {
    if (root._wanted === "") {
      root._timer.stop();
      return;
    }
    if (root._reader.running) {
      root._again = true;
      return;
    }
    // Each line names its zone, so a read started before this one ends
    // can't be taken for it
    root._reader.command = ["sh", "-c", 'for zone do printf "%s %s\\n" "$zone" "$(TZ="$zone" date +%z)"; done', "sh"].concat(root._wanted.split("\n"));
    root._reader.running = true;
  }

  property Process _reader: Process {
    stdout: StdioCollector {
      onStreamFinished: {
        const offsets = Object.assign({}, root._offsets);
        text.split("\n").forEach(line => {
          const space = line.lastIndexOf(" ");
          const offset = TimeZones.parseOffset(line.slice(space + 1));
          if (space > 0 && offset !== null)
            offsets[line.slice(0, space)] = offset;
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
