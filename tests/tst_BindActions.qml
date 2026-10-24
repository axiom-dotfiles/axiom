import QtQuick
import QtTest
import qs.components.methods

// BindActions: what each keybind action is (labels, sections, calls,
// arguments), checked against the schema's action list.
TestCase {
  id: test
  name: "BindActions"

  // Records the helpers' calls as shared fixtures for the axiom binary
  Shared {
    id: shared
    testCase: test
  }

  RepoFiles {
    id: files
  }

  function _schemaActions() {
    return files.json("config/json/config.schema.json").definitions.Keybind.properties.action.enum;
  }

  function test_everySchemaActionIsKnown() {
    for (const action of _schemaActions())
      verify(action === "exec" || BindActions.ipcActions[action] !== undefined || BindActions.compositorActions[action] !== undefined, action + " has no entry");
  }

  function test_noActionIsBoth() {
    for (const action of Object.keys(BindActions.ipcActions))
      verify(BindActions.compositorActions[action] === undefined, action + " is both an IPC and a compositor action");
  }

  function test_calls() {
    verify(shared.calls.BindActions.hasCalls("launcher"));
    verify(!shared.calls.BindActions.hasCalls("lock"));
    compare(shared.calls.BindActions.callOf({
      "action": "overlay",
      "call": "open"
    }), "open");
    compare(shared.calls.BindActions.callOf({
      "action": "lock",
      "call": "open"
    }), "toggle", "an action without calls always toggles");
    compare(shared.calls.BindActions.callFunction({
      "action": "workspaceOverview",
      "call": "close"
    }), "hide", "the call's IPC function");
    compare(shared.calls.BindActions.callFunction({
      "action": "overlay"
    }), "toggle");
  }

  function test_needsArgument() {
    verify(shared.calls.BindActions.needsArgument("exec"));
    verify(shared.calls.BindActions.needsArgument("workspaceNth"), "{0} in the IPC call");
    verify(shared.calls.BindActions.needsArgument("focusDir"), "{0} in a compositor action's label");
    verify(shared.calls.BindActions.needsArgument("raw"));
    verify(!shared.calls.BindActions.needsArgument("launcher"));
    verify(!shared.calls.BindActions.needsArgument("closeWindow"));
  }

  // An argument is needed exactly where the IPC call or the label has a
  // place for it ({0}), and by exec
  function test_argumentsMatchTheTemplates() {
    for (const action of _schemaActions()) {
      const template = BindActions.ipcActions[action]?.[0] ?? BindActions.compositorActions[action]?.[0] ?? "";
      compare(shared.calls.BindActions.needsArgument(action), action === "exec" || template.includes("{0}"), action);
    }
    compare(shared.calls.BindActions.argumentKind("workspaceNth"), "workspace");
    compare(shared.calls.BindActions.argumentKind("closeWindow"), "");
  }

  function test_labels() {
    compare(shared.calls.BindActions.sectionFor("volumeUp"), "Media");
    compare(shared.calls.BindActions.sectionFor("toggleSpecial"), "Special");
    compare(shared.calls.BindActions.sectionFor("nope"), "Axiom", "unknown actions file under Axiom");
    compare(shared.calls.BindActions.defaultLabel({
      "action": "workspaceNth",
      "argument": " 3 "
    }), "Go to workspace 3");
    compare(shared.calls.BindActions.defaultLabel({
      "action": "exec",
      "argument": "kitty"
    }), "kitty", "exec shows its command");
    compare(shared.calls.BindActions.defaultLabel({
      "action": "launcher",
      "call": "open"
    }), "App launcher (open)");
  }

  function test_descriptionFor() {
    compare(shared.calls.BindActions.descriptionFor({
      "action": "closeWindow"
    }), "Window: Close");
    compare(shared.calls.BindActions.descriptionFor({
      "action": "closeWindow",
      "description": "Kill it"
    }), "Window: Kill it");
    compare(shared.calls.BindActions.descriptionFor({
      "action": "closeWindow",
      "description": "Mine: Kill it"
    }), "Mine: Kill it", "a description naming its own section keeps it");
    verify(!shared.calls.BindActions.hasOwnSection("Mine:no space"));
  }

  function test_supported() {
    const hyprland = {
      "strips": true,
      "namedSpecial": true,
      "switcher": true
    };
    verify(shared.calls.BindActions.supported("closeWindow", {}), "needs nothing");
    verify(shared.calls.BindActions.supported("stripWider", hyprland));
    verify(!shared.calls.BindActions.supported("stripWider", {}));
    verify(shared.calls.BindActions.supported("toggleSpecial", {
      "scratchpad": true
    }), "any one of its capabilities");
    for (const action in BindActions.needs)
      verify(_schemaActions().includes(action), action + " is an action");
  }

  function test_appliesUnder() {
    const raw = {
      "action": "raw",
      "compositor": "hyprland",
      "argument": "hl.dsp.layout(\"swapsplit\")"
    };
    verify(shared.calls.BindActions.appliesUnder(raw, "hyprland", {}));
    verify(!shared.calls.BindActions.appliesUnder(raw, "sway", {}), "written for another compositor");
    verify(!shared.calls.BindActions.appliesUnder({
      "action": "pseudo"
    }, "sway", {}));
  }

  function test_tapsNeedModifierTap() {
    const tap = {
      "key": "Super_L",
      "action": "launcher"
    };
    verify(shared.calls.BindActions.appliesUnder(tap, "sway", {
      "modifierTap": true
    }));
    verify(!shared.calls.BindActions.appliesUnder(tap, "niri", {}));
    verify(shared.calls.BindActions.keySupported("SUPER + Q", {}));
  }
}
