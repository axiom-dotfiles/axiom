import QtQuick
import QtTest
import qs.components.methods

// The real schema: its defaults are a valid config, and every oneOf
// variant's and edge menu's defaults are valid. The whole-config calls go
// through Shared, so the axiom binary is checked against the same bytes.
TestCase {
  id: test
  name: "Config"

  // Records the helper calls as shared fixtures (Shared.qml)
  Shared {
    id: shared
    testCase: test
  }

  RepoFiles {
    id: files
  }

  property var schema

  function initTestCase() {
    schema = shared.schema;
  }

  function test_defaults_are_valid() {
    const defaults = shared.applyDefaults({}, schema);
    compare(defaults.format, 2);
    compare(defaults.version, schema.properties.version.default);
    compare(shared.validationErrors(defaults, schema), []);
  }

  function test_every_variant_default_is_valid_data() {
    const rows = [];
    for (const union of ["BarWidget", "OverlayModule", "OverlayView"]) {
      for (const option of schema.definitions[union].oneOf) {
        const name = option.$ref.split("/").pop();
        const type = schema.definitions[name].properties.type.const;
        rows.push({
          tag: union + ":" + type,
          union: union,
          type: type
        });
      }
    }
    return rows;
  }

  function test_every_variant_default_is_valid(data) {
    const unionSchema = {
      "$ref": "#/definitions/" + data.union
    };
    SchemaValidation._ctx.root = schema;
    // Format 2's items carry a stable id
    const filled = SchemaValidation.applyDefaults({
      "type": data.type,
      "id": "test"
    }, unionSchema, schema);
    compare(filled.type, data.type);
    // validationErrors takes the root schema for $refs, so wrap the value
    const wrapped = Object.assign({}, schema, {
      "type": "object",
      "properties": {
        "value": unionSchema
      },
      "additionalProperties": false,
      "required": []
    });
    compare(SchemaValidation.validationErrors({
      "value": filled
    }, wrapped), []);
  }

  function test_edge_menu_defaults_are_valid() {
    const menuSchema = schema.definitions.EdgeMenu;
    const filled = SchemaValidation.applyDefaults({
      "id": "test"
    }, menuSchema, schema);
    const wrapped = Object.assign({}, schema, {
      "type": "object",
      "properties": {
        "menu": {
          "$ref": "#/definitions/EdgeMenu"
        }
      },
      "additionalProperties": false,
      "required": []
    });
    compare(SchemaValidation.validationErrors({
      "menu": filled
    }, wrapped), []);
  }
}
