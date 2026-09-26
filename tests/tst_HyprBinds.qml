import QtQuick
import QtTest
import qs.components.methods

TestCase {
  name: "HyprBinds"

  // hyprctl binds -j entries, trimmed to what HyprBinds reads
  function entry(modmask, key, extra) {
    return Object.assign({
      "modmask": modmask,
      "key": key,
      "keycode": 0,
      "submap": ""
    }, extra ?? {});
  }

  function test_keyId() {
    compare(HyprBinds.keyId("SUPER + SHIFT + Space"), "65:space");
    compare(HyprBinds.keyId("mod4+control+Q"), "68:q");
    compare(HyprBinds.keyId("F12"), "0:f12");
    compare(HyprBinds.keyId(" SUPER + code:10 "), "64:code:10");
    compare(HyprBinds.keyId("HYPER + A"), "", "unknown modifier");
    compare(HyprBinds.keyId(""), "");
    compare(HyprBinds.keyId(undefined), "");
  }

  function test_entryId_matches_keyId() {
    compare(HyprBinds.entryId(entry(65, "Space")), HyprBinds.keyId("SUPER + SHIFT + space"));
    compare(HyprBinds.entryId(entry(64, "", {
      "keycode": 10
    })), HyprBinds.keyId("SUPER + code:10"));
  }

  function test_runtime_skips_keys_the_user_binds() {
    const binds = [
      {
        "key": "SUPER + Return"
      },
      {
        "key": "SUPER + SHIFT + Q"
      },
      {
        "key": "SUPER + code:10"
      },
      {
        "key": "SUPER + D"
      },
      {
        "key": "BOGUS + X"
      }
    ];
    const entries = [entry(64, "Return"), entry(65, "q"), entry(64, "", {
        "keycode": 10
      }), entry(64, "d", {
        "submap": "resize"
      })];
    const plan = HyprBinds.runtimeBinds(binds, entries);
    compare(plan.skipped, ["SUPER + Return", "SUPER + SHIFT + Q", "SUPER + code:10"]);
    // A submap's bind doesn't take the key outside it
    compare(plan.apply.map(bind => bind.key), ["SUPER + D"]);
    compare(plan.unreadable, ["BOGUS + X"]);
  }

  function test_runtime_with_nothing_bound() {
    const plan = HyprBinds.runtimeBinds([
      {
        "key": "SUPER + A"
      }
    ], []);
    compare(plan.apply.length, 1);
    compare(plan.skipped, []);
    compare(HyprBinds.runtimeBinds(undefined, undefined).apply, []);
  }

  function test_userKeyCounts_less_axioms_own() {
    const entries = [entry(64, "a"), entry(64, "a"), entry(64, "b"), entry(64, "c", {
        "submap": "resize"
      })];
    const counts = HyprBinds.userKeyCounts(entries, [
      {
        "key": "SUPER + A"
      },
      {
        "key": "SUPER + B"
      },
      {
        "key": "SUPER + Z"
      }
    ]);
    compare(counts["64:a"], 1);
    compare(counts["64:b"], 0);
    compare(counts["64:c"], undefined);
    compare(counts["64:z"], undefined);
  }
}
