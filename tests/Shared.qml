import QtQuick
import qs.components.methods

// The cases the JS helpers and the axiom binary (Go) must agree on
// (tests/fixtures/shared/, docs/dev/backend/fixtures.md). Each op calls one
// helper with JSON arguments and returns a JSON value; the expected output
// is that value's exact bytes (canonical()). Tests call the helpers through
// here: while scripts/dev/fixtures.py records, every call is logged as a
// case, so the inline cases of the tests become shared fixtures without
// being copied by hand. tst_Shared replays them.
QtObject {
  id: root

  // The TestCase whose calls are recorded (its name and current function
  // name the cases)
  property var testCase: null
  // The suite recorded calls go to, instead of their op's family
  property string suite: ""
  // Names the next recorded case instead of its test function
  property string label: ""

  // The schema the legacy (pre-v2) cases ran against, frozen with them
  readonly property string legacySchemaName: "legacy-v75"
  readonly property var legacySchema: _json("tests/fixtures/shared/schemas/legacy-v75.schema.json")

  readonly property bool recording: _read("tests/fixtures/shared/.recording") !== ""
  property int _calls: 0
  // Objects inside legacySchema by identity → their JSON pointer, so a
  // case can name a sub-schema instead of copying it
  property var _pointers: null

  // op → function(args) returning the output. Arguments arrive resolved
  // (schema references replaced by the schema objects)
  readonly property var ops: ({
      "legacy.migrate": args => ConfigMigration.migrate(args[0]),
      // What ConfigManager does with a parsed config.json, whole
      "legacy.load": args => {
        const migration = ConfigMigration.migrate(args[0]);
        const config = migration.config;
        const removed = SchemaValidation.pruneUnknown(config, args[1]);
        const filled = SchemaValidation.applyDefaults(config, args[1]);
        return {
          "config": filled,
          "removed": removed,
          "changes": migration.changes,
          "secrets": migration.secrets,
          "errors": SchemaValidation.validationErrors(filled, args[1])
        };
      },
      "schema.applyDefaults": args => SchemaValidation.applyDefaults(args[0], args[1], args.length > 2 ? args[2] : args[1]),
      // In place: the output is the pruned value and the removed paths
      "schema.pruneUnknown": args => {
        const removed = SchemaValidation.pruneUnknown(args[0], args[1]);
        return {
          "value": args[0],
          "removed": removed
        };
      },
      "schema.validationErrors": args => SchemaValidation.validationErrors(args[0], args[1]),
      "schema.resolveRef": args => SchemaValidation.resolveRef(args[0], args[1]),
      "share.pick": args => ConfigExamples.pick(args[0], args[1], args[2] ?? [], args[3] ?? null),
      "share.apply": args => ConfigExamples.apply(args[0], args[1], args[2], args[3] ?? [], args[4] ?? null),
      "share.sparse": args => ConfigExamples.sparse(args[0], args[1]),
      "share.snapshot": args => ConfigExamples.snapshot(args[0], args[1]),
      "share.snapshotFiles": args => ConfigExamples.snapshotFiles(args[0], args[1]),
      "share.snapshotPaths": args => ConfigExamples.snapshotPaths(args[0]),
      "share.takeoverPaths": args => ConfigExamples.takeoverPaths(args[0]),
      "share.keepTakeovers": args => ConfigExamples.keepTakeovers(args[0], args[1], args[2]),
      "share.keepMovedKeys": args => ConfigExamples.keepMovedKeys(args[0], args[1], args[2], args[3]),
      "share.withSnapshot": args => ConfigExamples.withSnapshot(args[0], args[1], args[2], args[3]),
      "share.monitorOrder": args => ConfigExamples.monitorOrder(args[0])
    })

  // The exact bytes an output is compared by: 2-space JSON, JS key order,
  // a trailing newline (undefined is written as null)
  function canonical(value) {
    return (value === undefined ? "null" : JSON.stringify(value, null, 2)) + "\n";
  }

  // Calls op with args, recording the call while fixtures are recorded
  function call(op, args) {
    const recorded = recording ? _caseText(op, args) : "";
    const output = ops[op](args);
    if (recording)
      _record(op, recorded, canonical(output));
    return output;
  }

  // A recorded case's arguments with schema references resolved
  function resolveArgs(args) {
    return _resolve(JSON.parse(JSON.stringify(args)));
  }

  // The helpers, by their own names, for the tests to call

  function migrate(config) {
    return call("legacy.migrate", [config]);
  }
  function applyDefaults(value, schema, rootSchema) {
    return call("schema.applyDefaults", rootSchema === undefined ? [value, schema] : [value, schema, rootSchema]);
  }
  // Prunes `value` in place, as SchemaValidation.pruneUnknown does
  function pruneUnknown(value, schema) {
    const result = call("schema.pruneUnknown", [value, schema]);
    if (result.value !== value)
      _replaceContents(value, result.value);
    return result.removed;
  }
  function validationErrors(value, schema) {
    return call("schema.validationErrors", [value, schema]);
  }
  function resolveRef(schema, rootSchema) {
    return call("schema.resolveRef", [schema, rootSchema]);
  }
  function pick(config, schema, carry, monitors) {
    return call("share.pick", [config, schema, carry ?? [], monitors ?? null]);
  }
  function apply(current, example, schema, carry, monitors) {
    return call("share.apply", [current, example, schema, carry ?? [], monitors ?? null]);
  }
  function sparse(config, schema) {
    return call("share.sparse", [config, schema]);
  }
  function snapshot(config, schema) {
    return call("share.snapshot", [config, schema]);
  }
  function snapshotFiles(config, schema) {
    return call("share.snapshotFiles", [config, schema]);
  }
  function snapshotPaths(schema) {
    return call("share.snapshotPaths", [schema]);
  }
  function takeoverPaths(schema) {
    return call("share.takeoverPaths", [schema]);
  }
  function keepTakeovers(config, current, paths) {
    return call("share.keepTakeovers", [config, current, paths]);
  }
  function keepMovedKeys(config, held, current, version) {
    return call("share.keepMovedKeys", [config, held, current, version]);
  }
  function withSnapshot(config, saved, schema, existing) {
    return call("share.withSnapshot", [config, saved, schema, existing]);
  }
  function monitorOrder(outputs) {
    return call("share.monitorOrder", [outputs]);
  }

  // --- recording ---

  function _caseText(op, args) {
    return JSON.stringify({
      "op": op,
      "args": _refs(args)
    }, null, 2) + "\n";
  }

  // Logs one call for scripts/dev/fixtures.py. The payload goes as hex
  // UTF-16 code units: Qt's logging re-encodes text, which would change
  // the bytes the case is compared by.
  function _record(op, caseText, expectedText) {
    const results = testCase?.qtest_results;
    const payload = JSON.stringify({
      "suite": suite || op.split(".")[0],
      "test": testCase?.name ?? "",
      "function": results?.functionName ?? "",
      "tag": results?.dataTag ?? "",
      "label": label,
      "index": _calls++,
      "case": caseText,
      "expected": expectedText
    });
    let hex = "";
    for (let i = 0; i < payload.length; i++)
      hex += ("000" + payload.charCodeAt(i).toString(16)).slice(-4);
    console.log("@@FIXTURE " + hex);
  }

  // args with every object of the legacy schema replaced by a reference
  function _refs(value) {
    if (value === null || typeof value !== "object")
      return value;
    if (value === legacySchema)
      return {
        "$fixtureSchema": legacySchemaName
      };
    const pointer = _pointerOf(value);
    if (pointer !== undefined)
      return {
        "$fixtureSchema": legacySchemaName,
        "pointer": pointer
      };
    if (Array.isArray(value))
      return value.map(v => _refs(v));
    const out = {};
    for (const key in value)
      out[key] = _refs(value[key]);
    return out;
  }

  function _pointerOf(value) {
    if (_pointers === null) {
      const found = new Map();
      const walk = (node, pointer) => {
        if (node === null || typeof node !== "object")
          return;
        if (pointer !== "")
          found.set(node, pointer);
        for (const key in node)
          walk(node[key], pointer + "/" + String(key).replace(/~/g, "~0").replace(/\//g, "~1"));
      };
      walk(legacySchema, "");
      _pointers = found;
    }
    return _pointers.get(value);
  }

  function _resolve(value) {
    if (value === null || typeof value !== "object")
      return value;
    // Large arguments are stored once, by hash (scripts/dev/fixtures.py)
    if (!Array.isArray(value) && typeof value.$blob === "string" && Object.keys(value).length === 1)
      return _resolve(_json("tests/fixtures/shared/blobs/" + value.$blob + ".json"));
    if (!Array.isArray(value) && typeof value.$fixtureSchema === "string" && Object.keys(value).every(k => k === "$fixtureSchema" || k === "pointer")) {
      let node = _schemaNamed(value.$fixtureSchema);
      for (const part of (value.pointer ?? "").split("/").slice(1))
        node = node[part.replace(/~1/g, "/").replace(/~0/g, "~")];
      return node;
    }
    if (Array.isArray(value))
      return value.map(v => _resolve(v));
    for (const key in value)
      value[key] = _resolve(value[key]);
    return value;
  }

  function _schemaNamed(name) {
    if (name === legacySchemaName)
      return legacySchema;
    return _json("tests/fixtures/shared/schemas/" + name + ".schema.json");
  }

  function _replaceContents(target, source) {
    for (const key of Object.keys(target))
      delete target[key];
    Object.assign(target, source);
  }

  // Files by path from the repo root (as RepoFiles, which this can't use
  // from its own bindings: they may run before a child object exists)
  function _read(path) {
    const xhr = new XMLHttpRequest();
    xhr.open("GET", Qt.resolvedUrl("../" + path), false);
    xhr.send();
    return xhr.responseText;
  }

  function _json(path) {
    const text = _read(path);
    if (text === "")
      throw new Error("empty or unreadable: " + path);
    return JSON.parse(text);
  }
}
