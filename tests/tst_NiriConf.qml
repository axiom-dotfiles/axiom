import QtQuick
import QtTest
import qs.components.methods

// NiriConf: niri's config text and requests from axiom's settings. The
// files also go to tests/.out/ as *.niri.kdl, which run_tests.sh has niri
// itself validate where it's installed.
TestCase {
  id: test
  name: "NiriConf"

  // Records the helpers' calls as shared fixtures for the axiom binary
  Shared {
    id: shared
    testCase: test
  }

  RepoFiles {
    id: files
  }

  readonly property var ctx: ({
      "axiomPath": "/opt/axiom",
      "axiomBin": "/usr/bin/axiom",
      "shellCommand": "'/usr/bin/axiom'",
      "restartCommand": "'/usr/bin/axiom' restart",
      "terminal": "foot",
      "fileManager": "nautilus",
      "browser": "firefox"
    })
  readonly property var schema: files.json("config/json/config.schema.json").properties

  function _write(path, text) {
    const written = files.write(path, text);
    tryVerify(() => written.done, 2000);
  }

  // --- KDL ---

  function bindText(bind) {
    const n = shared.calls.NiriConf.bindNode(bind, ctx);
    return n ? shared.calls.NiriConf.serialize([n]) : "";
  }

  // WindowLook with every part off, `parts` over it
  function lookOf(parts, shadow) {
    const values = {};
    for (const part of CompositorLayer.lookPartNames)
      values[part] = Object.assign({
        "enabled": false
      }, parts[part] ?? {});
    return shared.calls.CompositorLayer.look(values, {
      "activeHex": "89b4fa",
      "inactiveHex": "45475a",
      "borderWidth": 2,
      "radius": 10,
      "surfacesBlur": true,
      "shadow": shadow ?? null
    });
  }

  readonly property var rules: [
    {
      "output": "desc:Dell Inc. U2720Q 1234",
      "mode": "3840x2160@60",
      "x": 0,
      "y": 0,
      "scale": 1.5,
      "transform": 1,
      "vrr": 2
    },
    {
      "output": "HDMI-A-1",
      "disabled": true
    }
  ]

  function test_outputRequests() {
    const requests = shared.calls.NiriConf.outputRequests(rules, [
      {
        "name": "DP-1",
        "description": "Dell Inc. U2720Q 1234"
      }
    ]);
    compare(requests[0], {
      "Output": {
        "output": "DP-1",
        "action": "On"
      }
    });
    compare(requests[1].Output.action.Mode.mode.Specific, {
      "width": 3840,
      "height": 2160,
      "refresh": 60
    });
    compare(requests.map(r => r.Output.output), ["DP-1", "DP-1", "DP-1", "DP-1", "DP-1", "DP-1", "HDMI-A-1"]);
    compare(requests[requests.length - 1].Output.action, "Off");
    compare(requests[3].Output.action.Transform.transform, "_90");
    compare(requests[5].Output.action.Vrr.vrr, {
      "vrr": true,
      "on_demand": true
    });
    // A description nothing connected has: left out
    compare(shared.calls.NiriConf.outputRequests([rules[0]], []), []);
  }
}
