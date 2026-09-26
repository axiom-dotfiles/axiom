import QtQuick
import QtTest
import qs.components.methods

TestCase {
  name: "SchemaValidation"

  readonly property var schema: ({
      "type": "object",
      "additionalProperties": false,
      "properties": {
        "size": {
          "type": "integer",
          "default": 10,
          "minimum": 1,
          "maximum": 20
        },
        "mode": {
          "type": "string",
          "default": "a",
          "enum": ["a", "b"]
        },
        "nested": {
          "type": "object",
          "additionalProperties": false,
          "properties": {
            "on": {
              "type": "boolean",
              "default": true
            }
          }
        },
        "widgets": {
          "type": "array",
          "default": [],
          "items": {
            "$ref": "#/definitions/Widget"
          }
        },
        "free": {
          "type": "object",
          "additionalProperties": {
            "type": "integer"
          }
        }
      },
      "definitions": {
        "Widget": {
          "oneOf": [
            {
              "$ref": "#/definitions/Clock"
            },
            {
              "$ref": "#/definitions/Label"
            }
          ]
        },
        "Clock": {
          "type": "object",
          "additionalProperties": false,
          "required": ["type"],
          "properties": {
            "type": {
              "const": "Clock"
            },
            "format": {
              "type": "string",
              "default": "HH:mm"
            }
          }
        },
        "Label": {
          "type": "object",
          "additionalProperties": false,
          "required": ["type", "text"],
          "properties": {
            "type": {
              "const": "Label"
            },
            "text": {
              "type": "string"
            }
          }
        }
      }
    })

  function errors(value) {
    return SchemaValidation.validationErrors(value, schema);
  }

  function test_defaults_fill_everything() {
    const filled = SchemaValidation.applyDefaults({}, schema);
    compare(filled.size, 10);
    compare(filled.mode, "a");
    compare(filled.nested.on, true);
    compare(filled.widgets.length, 0);
    compare(errors(filled), []);
  }

  function test_defaults_keep_values_and_do_not_mutate() {
    const input = {
      "size": 3,
      "nested": {
        "on": false
      }
    };
    const filled = SchemaValidation.applyDefaults(input, schema);
    compare(filled.size, 3);
    compare(filled.nested.on, false);
    compare(input.mode, undefined);
  }

  function test_defaults_follow_oneOf_by_type() {
    const filled = SchemaValidation.applyDefaults({
      "widgets": [
        {
          "type": "Clock"
        },
        {
          "type": "Label",
          "text": "hi"
        }
      ]
    }, schema);
    compare(filled.widgets[0].format, "HH:mm");
    compare(filled.widgets[1].format, undefined);
    compare(errors(filled), []);
  }

  function test_type_errors() {
    verify(errors({
      "size": "big"
    }).length === 1);
    verify(errors({
      "size": 1.5
    }).length === 1);
    verify(errors({
      "nested": []
    }).length === 1);
  }

  function test_range_and_enum() {
    verify(errors({
      "size": 0
    })[0].includes("minimum"));
    verify(errors({
      "size": 21
    })[0].includes("maximum"));
    verify(errors({
      "mode": "c"
    })[0].includes("not in allowed values"));
  }

  function test_additional_properties() {
    verify(errors({
      "stray": 1
    })[0].includes("additional property"));
    compare(errors({
      "free": {
        "x": 1
      }
    }), []);
    verify(errors({
      "free": {
        "x": "no"
      }
    }).length === 1);
  }

  function test_oneOf_reports_the_matching_option() {
    const found = errors({
      "widgets": [
        {
          "type": "Label"
        }
      ]
    });
    compare(found.length, 1);
    verify(found[0].includes("text: required field missing"), found[0]);
    verify(errors({
      "widgets": [
        {
          "type": "Nope"
        }
      ]
    })[0].includes("does not match any schema"));
  }

  function test_prune_removes_unknown_keys_in_place() {
    const value = {
      "size": 2,
      "stray": true,
      "nested": {
        "on": true,
        "old": 1
      },
      "widgets": [
        {
          "type": "Clock",
          "gone": 1
        }
      ],
      "free": {
        "kept": 1
      }
    };
    const removed = SchemaValidation.pruneUnknown(value, schema);
    compare(removed.sort(), ["nested.old", "stray", "widgets[0].gone"]);
    compare(value.stray, undefined);
    compare(value.free.kept, 1);
    compare(errors(value), []);
  }

  function test_getSchemaProperty() {
    compare(SchemaValidation.getSchemaProperty(schema, "nested.on").type, "boolean");
    compare(SchemaValidation.getSchemaProperty(schema, "nested.missing"), null);
  }
}
