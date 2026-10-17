import QtQuick
import QtTest
import qs.components.methods

TestCase {
  name: "BindKeys"

  // hyprctl binds -j entries, trimmed to what BindKeys reads
  function entry(modmask, key, extra) {
    return Object.assign({
      "modmask": modmask,
      "key": key,
      "keycode": 0,
      "submap": ""
    }, extra ?? {});
  }

  function test_keyId() {
    compare(BindKeys.keyId("SUPER + SHIFT + Space"), "65:space");
    compare(BindKeys.keyId("mod4+control+Q"), "68:q");
    compare(BindKeys.keyId("F12"), "0:f12");
    compare(BindKeys.keyId(" SUPER + code:10 "), "64:code:10");
    compare(BindKeys.keyId("HYPER + A"), "", "unknown modifier");
    compare(BindKeys.keyId(""), "");
    compare(BindKeys.keyId(undefined), "");
  }

  function test_entryId_matches_keyId() {
    compare(BindKeys.entryId(entry(65, "Space")), BindKeys.keyId("SUPER + SHIFT + space"));
    compare(BindKeys.entryId(entry(64, "", {
      "keycode": 10
    })), BindKeys.keyId("SUPER + code:10"));
  }

  function test_tapIds() {
    // Hyprland lists a tap with its modifier held, sway without
    compare(BindKeys.keyId("Super_L"), "0:super_l");
    compare(BindKeys.keyId("SUPER + Super_L"), "0:super_l");
    compare(BindKeys.entryId(entry(64, "SUPER_L")), "0:super_l");
    compare(BindKeys.entryId(entry(0, "Super_L")), "0:super_l");
    compare(BindKeys.keyId("CTRL + Super_L"), "4:super_l", "not a tap");
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
    const plan = BindKeys.runtimeBinds(binds, entries);
    compare(plan.skipped, ["SUPER + Return", "SUPER + SHIFT + Q", "SUPER + code:10"]);
    // A submap's bind doesn't take the key outside it
    compare(plan.apply.map(bind => bind.key), ["SUPER + D"]);
    compare(plan.unreadable, ["BOGUS + X"]);
  }

  function test_runtime_with_nothing_bound() {
    const plan = BindKeys.runtimeBinds([
      {
        "key": "SUPER + A"
      }
    ], []);
    compare(plan.apply.length, 1);
    compare(plan.skipped, []);
    compare(BindKeys.runtimeBinds(undefined, undefined).apply, []);
  }

  function test_userKeyCounts_less_axioms_own() {
    const entries = [entry(64, "a"), entry(64, "a"), entry(64, "b"), entry(64, "c", {
        "submap": "resize"
      })];
    const counts = BindKeys.userKeyCounts(entries, [
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

  function test_mergeBinds_one_bind_per_key() {
    const axiom = [
      {
        "key": "SUPER + Q",
        "action": "overlay"
      },
      {
        "key": "",
        "action": "lock"
      },
      {
        "key": "SUPER + E",
        "action": "fileManager"
      }
    ];
    const user = [
      {
        "key": "super+q",
        "action": "exec",
        "argument": "kitty"
      },
      {
        "key": "SUPER + R",
        "action": "exec",
        "argument": "a"
      },
      {
        "key": "SUPER + R",
        "action": "exec",
        "argument": "b"
      },
      {
        "key": "",
        "action": "pin"
      }
    ];
    const merged = BindKeys.mergeBinds(axiom, user);
    compare(merged.map(bind => bind.action), ["exec", "lock", "fileManager", "exec", "pin"]);
    compare(merged[0].argument, "kitty");
    compare(merged[3].argument, "b");
    // The inputs are left as they were
    compare(axiom[0].action, "overlay");
    compare(BindKeys.mergeBinds(axiom, []), axiom);
  }
}
