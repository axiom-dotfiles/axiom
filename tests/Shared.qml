import QtQuick
import qs.components.methods

// The cases the JS helpers and the axiom binary (Go) must agree on
// (tests/fixtures/shared/, docs/dev/backend/README.md › Shared fixtures):
// SchemaValidation, which the shell still validates with and fills defaults
// from, against the binary's config pipeline. Each op calls one
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

  // The live schema, which a case names by its path instead of copying it
  readonly property string schemaPath: "config/json/config.schema.json"
  readonly property var schema: _json(schemaPath)

  readonly property bool recording: _read("tests/fixtures/shared/.recording") !== ""
  property int _calls: 0

  // op → function(args) returning the output
  readonly property var ops: ({
      "schema.applyDefaults": args => SchemaValidation.applyDefaults(args[0], args[1], args.length > 2 ? args[2] : args[1]),
      "schema.validationErrors": args => SchemaValidation.validationErrors(args[0], args[1]),
      "schema.resolveRef": args => SchemaValidation.resolveRef(args[0], args[1])
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

  // A recorded case's arguments with blobs resolved
  function resolveArgs(args) {
    return _resolve(JSON.parse(JSON.stringify(args)));
  }

  // The helpers, by their own names, for the tests to call

  function applyDefaults(value, schema, rootSchema) {
    return call("schema.applyDefaults", rootSchema === undefined ? [value, schema] : [value, schema, rootSchema]);
  }
  function validationErrors(value, schema) {
    return call("schema.validationErrors", [value, schema]);
  }
  function resolveRef(schema, rootSchema) {
    return call("schema.resolveRef", [schema, rootSchema]);
  }

  // --- recording ---

  function _caseText(op, args) {
    return JSON.stringify({
      "op": op,
      "args": args.map(arg => arg === root.schema ? {
          "$repoFile": root.schemaPath
        } : arg)
    }, null, 2) + "\n";
  }

  // Logs one call for scripts/dev/fixtures.py. The payload goes as hex
  // UTF-16 code units: Qt's logging re-encodes text, which would change
  // the bytes the case is compared by.
  function _record(op, caseText, expectedText) {
    const results = testCase?.qtest_results;
    const payload = JSON.stringify({
      "suite": op.split(".")[0],
      "test": testCase?.name ?? "",
      "function": results?.functionName ?? "",
      "tag": results?.dataTag ?? "",
      "label": "",
      "index": _calls++,
      "case": caseText,
      "expected": expectedText
    });
    let hex = "";
    for (let i = 0; i < payload.length; i++)
      hex += ("000" + payload.charCodeAt(i).toString(16)).slice(-4);
    console.log("@@FIXTURE " + hex);
  }

  function _resolve(value) {
    if (value === null || typeof value !== "object")
      return value;
    // Large arguments are stored once, by hash (scripts/dev/fixtures.py)
    if (!Array.isArray(value) && typeof value.$blob === "string" && Object.keys(value).length === 1)
      return _resolve(_json("tests/fixtures/shared/blobs/" + value.$blob + ".json"));
    if (!Array.isArray(value) && typeof value.$repoFile === "string" && Object.keys(value).length === 1)
      return value.$repoFile === root.schemaPath ? root.schema : _json(value.$repoFile);
    if (Array.isArray(value))
      return value.map(v => _resolve(v));
    for (const key in value)
      value[key] = _resolve(value[key]);
    return value;
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
