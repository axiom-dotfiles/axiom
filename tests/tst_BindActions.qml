import QtQuick
import QtTest
import qs.components.methods

// BindActions: what each keybind action is (labels, sections, calls,
// arguments), checked against the schema's action list.
TestCase {
  name: "BindActions"

  RepoFiles {
    id: files
  }

  function _schemaActions() {
    return files.json("config/json/config.schema.json").properties.Keybinds.properties.binds.items.properties.action.enum;
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
    verify(BindActions.hasCalls("launcher"));
    verify(!BindActions.hasCalls("lock"));
    compare(BindActions.callOf({
      "action": "overlay",
      "call": "open"
    }), "open");
    compare(BindActions.callOf({
      "action": "lock",
      "call": "open"
    }), "toggle", "an action without calls always toggles");
    compare(BindActions.callFunction({
      "action": "workspaceOverview",
      "call": "close"
    }), "hide", "the call's IPC function");
    compare(BindActions.callFunction({
      "action": "overlay"
    }), "toggle");
  }

  function test_needsArgument() {
    verify(BindActions.needsArgument("exec"));
    verify(BindActions.needsArgument("workspaceNth"), "{0} in the IPC call");
    verify(BindActions.needsArgument("focusDir"), "{0} in a compositor action's label");
    verify(BindActions.needsArgument("raw"));
    verify(!BindActions.needsArgument("launcher"));
    verify(!BindActions.needsArgument("closeWindow"));
  }

  // An argument is needed exactly where the IPC call or the label has a
  // place for it ({0}), and by exec
  function test_argumentsMatchTheTemplates() {
    for (const action of _schemaActions()) {
      const template = BindActions.ipcActions[action]?.[0] ?? BindActions.compositorActions[action]?.[0] ?? "";
      compare(BindActions.needsArgument(action), action === "exec" || template.includes("{0}"), action);
    }
    compare(BindActions.argumentKind("workspaceNth"), "workspace");
    compare(BindActions.argumentKind("closeWindow"), "");
  }

  function test_labels() {
    compare(BindActions.sectionFor("volumeUp"), "Media");
    compare(BindActions.sectionFor("toggleSpecial"), "Special");
    compare(BindActions.sectionFor("nope"), "Axiom", "unknown actions file under Axiom");
    compare(BindActions.defaultLabel({
      "action": "workspaceNth",
      "argument": " 3 "
    }), "Go to workspace 3");
    compare(BindActions.defaultLabel({
      "action": "exec",
      "argument": "kitty"
    }), "kitty", "exec shows its command");
    compare(BindActions.defaultLabel({
      "action": "launcher",
      "call": "open"
    }), "App launcher (open)");
  }

  function test_descriptionFor() {
    compare(BindActions.descriptionFor({
      "action": "closeWindow"
    }), "Window: Close");
    compare(BindActions.descriptionFor({
      "action": "closeWindow",
      "description": "Kill it"
    }), "Window: Kill it");
    compare(BindActions.descriptionFor({
      "action": "closeWindow",
      "description": "Mine: Kill it"
    }), "Mine: Kill it", "a description naming its own section keeps it");
    verify(!BindActions.hasOwnSection("Mine:no space"));
  }

  function test_supported() {
    const hyprland = {
      "strips": true,
      "namedSpecial": true,
      "switcher": true
    };
    verify(BindActions.supported("closeWindow", {}), "needs nothing");
    verify(BindActions.supported("stripWider", hyprland));
    verify(!BindActions.supported("stripWider", {}));
    verify(BindActions.supported("toggleSpecial", {
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
    verify(BindActions.appliesUnder(raw, "hyprland", {}));
    verify(!BindActions.appliesUnder(raw, "sway", {}), "written for another compositor");
    verify(!BindActions.appliesUnder({
      "action": "pseudo"
    }, "sway", {}));
  }
}
