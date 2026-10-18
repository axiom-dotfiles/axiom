import QtQuick
import QtTest
import qs.components.methods

TestCase {
  name: "ShellInstances"

  function instance(pid, time) {
    return {
      "pid": pid,
      "launch_time": time
    };
  }

  function test_alone() {
    compare(ShellInstances.decide([instance(10, "2026-10-18T11:00:00")], 10), {
      "quit": false,
      "end": []
    });
    compare(ShellInstances.decide([], 10), {
      "quit": false,
      "end": []
    });
  }

  function test_newestEndsTheOthers() {
    const list = [instance(30, "2026-10-18T11:00:00"), instance(10, "2026-10-18T11:05:00"), instance(20, "2026-10-18T10:00:00")];
    compare(ShellInstances.decide(list, 10), {
      "quit": false,
      "end": [30, 20]
    });
  }

  function test_olderQuits() {
    const list = [instance(30, "2026-10-18T11:00:00"), instance(10, "2026-10-18T11:05:00")];
    compare(ShellInstances.decide(list, 30), {
      "quit": true,
      "end": []
    });
  }

  // Started in the same second: the higher pid wins, the same for both
  function test_sameSecondByPid() {
    const list = [instance(41, "2026-10-18T11:00:00"), instance(42, "2026-10-18T11:00:00")];
    compare(ShellInstances.decide(list, 42).end, [41]);
    verify(ShellInstances.decide(list, 41).quit);
  }

  // Not listed (yet): never quits on a list it isn't in
  function test_selfMissing() {
    const list = [instance(30, "2026-10-18T11:00:00"), instance(31, "2026-10-18T11:05:00")];
    compare(ShellInstances.decide(list, 10), {
      "quit": false,
      "end": []
    });
  }

  function test_badEntries() {
    compare(ShellInstances.decide([instance(10, "2026-10-18T11:00:00"),
      {
        "pid": -1
      },
      null], 10).end, []);
  }
}
