import QtQuick
import QtTest
import qs.components.methods

// SwayConf: sway's command and config text from axiom's settings.
TestCase {
  name: "SwayConf"

  function test_quote() {
    compare(SwayConf.quote("DP-1"), "DP-1");
    compare(SwayConf.quote("AOC CU34G4Z XJ9"), "\"AOC CU34G4Z XJ9\"");
    compare(SwayConf.quote("say \"hi\""), "\"say \\\"hi\\\"\"");
  }

  function test_outputCommand() {
    compare(SwayConf.outputCommand({
      "output": "desc:AOC CU34G4Z XJ9",
      "mode": "3440x1440@240",
      "x": 15,
      "y": 83,
      "scale": 1,
      "transform": 0,
      "vrr": 1
    }), "output \"AOC CU34G4Z XJ9\" enable mode 3440x1440@240Hz pos 15 83 scale 1 transform normal adaptive_sync on");
    compare(SwayConf.outputCommand({
      "output": "HDMI-A-1",
      "mode": "preferred",
      "x": 0,
      "y": 0,
      "scale": 1.5,
      "transform": 5,
      "bitdepth": 10
    }), "output HDMI-A-1 enable pos 0 0 scale 1.5 transform flipped-90 adaptive_sync off render_bit_depth 10");
    compare(SwayConf.outputCommand({
      "output": "DP-2",
      "disabled": true
    }), "output DP-2 disable");
  }

  function test_outputCommandsDisableLast() {
    compare(SwayConf.outputCommands([
      {
        "output": "DP-2",
        "disabled": true
      },
      {
        "output": "DP-1",
        "mode": "1920x1080"
      }
    ]), "output DP-1 enable mode 1920x1080 pos 0 0 scale 1 transform normal adaptive_sync off; output DP-2 disable");
  }
}
