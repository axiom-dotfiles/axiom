import QtQuick
import QtTest
import qs.components.methods

TestCase {
  name: "PolkitAgents"

  function test_isAgentCommand_data() {
    return [
      {
        "tag": "systemd unit",
        "command": "systemctl --user start hyprpolkitagent",
        "expected": true
      },
      {
        "tag": "unit with suffix",
        "command": "systemctl --user start plasma-polkit-agent.service",
        "expected": true
      },
      {
        "tag": "path",
        "command": "/usr/lib/polkit-gnome/polkit-gnome-authentication-agent-1",
        "expected": true
      },
      {
        "tag": "quoted path",
        "command": "'/usr/lib/polkit-kde-authentication-agent-1'",
        "expected": true
      },
      {
        "tag": "bare name with argument",
        "command": "lxpolkit --verbose",
        "expected": true
      },
      {
        "tag": "other command",
        "command": "hypridle",
        "expected": false
      },
      {
        "tag": "name inside another word",
        "command": "my-hyprpolkitagent-wrapper",
        "expected": false
      },
      {
        "tag": "empty",
        "command": "",
        "expected": false
      }
    ];
  }

  function test_isAgentCommand(data) {
    compare(PolkitAgents.isAgentCommand(data.command), data.expected);
  }

  function test_processPattern() {
    const pattern = new RegExp(PolkitAgents.processPattern);
    verify(pattern.test("/usr/lib/hyprpolkitagent/hyprpolkitagent"));
    verify(pattern.test("/usr/lib/polkit-kde-authentication-agent-1 --flag"));
    verify(pattern.test("soteria"));
    verify(!pattern.test("/usr/lib/polkit-1/polkitd --no-debug"), "polkitd itself isn't an agent");
    verify(!pattern.test("vim hyprpolkitagent.conf"));
  }

  function test_units() {
    verify(PolkitAgents.units.includes("hyprpolkitagent.service"));
    verify(!PolkitAgents.units.includes(""));
  }
}
