import QtQuick
import QtTest
import qs.components.methods

TestCase {
  name: "HypridleConf"

  readonly property var ctx: ({
      "lockCmd": "qs -p '/axiom' ipc call lockscreen lock",
      "shellCommand": "qs -p '/axiom'",
      "dpmsOff": "off-cmd",
      "dpmsOn": "on-cmd"
    })

  // The Idle section's defaults, with overrides
  function idle(extra) {
    return Object.assign({
      "enabled": true,
      "dimTimeout": 150,
      "dimMode": "to",
      "dimLevel": 30,
      "dimBy": 50,
      "lockTimeout": 300,
      "screenOffTimeout": 330,
      "suspendTimeout": 0,
      "lockBeforeSleep": true,
      "screenOnAfterSleep": true,
      "respectInhibitors": true,
      "listeners": []
    }, extra ?? {});
  }

  function test_defaults() {
    const text = HypridleConf.render(idle(), ctx);
    verify(text.includes("lock_cmd = qs -p '/axiom' ipc call lockscreen lock"));
    verify(text.includes("before_sleep_cmd = loginctl lock-session"));
    verify(text.includes("after_sleep_cmd = on-cmd"));
    verify(!text.includes("ignore_dbus_inhibit"));
    verify(text.includes("on-timeout = qs -p '/axiom' ipc call brightness dim 30"));
    verify(!text.includes("systemctl suspend"), "suspend is off by default");
    compare(text.split("listener {").length - 1, 3);
  }

  function test_dim_by() {
    const text = HypridleConf.render(idle({
      "dimMode": "by",
      "dimBy": 40
    }), ctx);
    verify(text.includes("on-timeout = qs -p '/axiom' ipc call brightness dimBy 40"));
    verify(!text.includes("brightness dim 30"));
  }

  function test_all_steps_off_leaves_general_only() {
    const text = HypridleConf.render(idle({
      "dimTimeout": 0,
      "lockTimeout": 0,
      "screenOffTimeout": 0,
      "lockBeforeSleep": false,
      "screenOnAfterSleep": false,
      "respectInhibitors": false
    }), ctx);
    verify(!text.includes("listener"));
    verify(text.includes("ignore_dbus_inhibit = true"));
    verify(text.includes("ignore_systemd_inhibit = true"));
    verify(!text.includes("before_sleep_cmd"));
  }

  function test_listeners_in_timeout_order() {
    const timeouts = HypridleConf.listeners(idle({
      "dimTimeout": 600,
      "lockTimeout": 60,
      "screenOffTimeout": 60,
      "suspendTimeout": 900
    }), ctx).map(listener => listener.onTimeout);
    compare(timeouts, ["loginctl lock-session", "off-cmd", "qs -p '/axiom' ipc call brightness dim 30", "systemctl suspend"]);
  }

  function test_own_listeners_skip_disabled_and_empty() {
    const own = HypridleConf.listeners(idle({
      "dimTimeout": 0,
      "lockTimeout": 0,
      "screenOffTimeout": 0,
      "listeners": [
        {
          "enabled": true,
          "timeout": 10,
          "onTimeout": " notify-send idle ",
          "onResume": ""
        },
        {
          "enabled": false,
          "timeout": 20,
          "onTimeout": "off",
          "onResume": ""
        },
        {
          "enabled": true,
          "timeout": 30,
          "onTimeout": "  ",
          "onResume": "x"
        }
      ]
    }), ctx);
    compare(own.length, 1);
    compare(own[0].onTimeout, "notify-send idle");
  }

  function test_no_lock_cmd() {
    const text = HypridleConf.render(idle(), Object.assign({}, ctx, {
      "lockCmd": ""
    }));
    verify(!text.includes("lock_cmd"));
  }

  function test_hash_is_escaped() {
    const text = HypridleConf.render(idle({
      "listeners": [
        {
          "enabled": true,
          "timeout": 5,
          "onTimeout": "echo '#1'",
          "onResume": ""
        }
      ]
    }), ctx);
    verify(text.includes("on-timeout = echo '##1'"));
  }
}
