import QtQuick
import QtTest
import qs.components.methods

// The Lua it writes also goes to tests/.out/, where scripts/run_tests.sh
// checks it with `luac -p`.
TestCase {
  name: "HyprLua"

  RepoFiles {
    id: files
  }

  readonly property var fieldSchema: ({
      "properties": {
        "gaps": {
          "type": "integer",
          "default": 5,
          "x-hypr": "general.gaps_in"
        },
        "both": {
          "type": "integer",
          "default": 0,
          "x-hypr": ["a.one", "a.two"]
        },
        "opacity": {
          "type": "integer",
          "default": 100,
          "x-hypr": "decoration.active_opacity",
          "x-hyprScale": 0.01
        },
        "flag": {
          "type": "boolean",
          "default": false,
          "x-hypr": "misc.flag",
          "x-hyprValue": "int"
        },
        "border": {
          "type": "string",
          "default": "base0D",
          "x-hypr": "general.col.active_border",
          "x-hyprValue": "color",
          "x-hyprAlpha": "cc"
        },
        "always": {
          "type": "string",
          "default": "dwindle",
          "x-hypr": "general.layout",
          "x-hyprAlways": true
        },
        "gated": {
          "type": "integer",
          "default": 3,
          "x-hypr": "blur.size",
          "x-hyprIf": "blur"
        },
        "blur": {
          "type": "boolean",
          "default": false
        },
        "unmapped": {
          "type": "integer",
          "default": 1
        }
      }
    })

  function hex(name) {
    return name === "base0D" ? "112233" : "445566";
  }

  function test_string_escapes() {
    compare(HyprLua.string('a "b" \\ c\nd'), '"a \\"b\\" \\\\ c\\nd"');
  }

  function test_value() {
    compare(HyprLua.value(0.1 + 0.2), "0.3");
    compare(HyprLua.value(true), "true");
    compare(HyprLua.value("x"), '"x"');
  }

  function test_defaults_write_only_always_fields() {
    const values = {
      "gaps": 5,
      "both": 0,
      "opacity": 100,
      "flag": false,
      "border": "base0D",
      "always": "dwindle",
      "gated": 3,
      "blur": false,
      "unmapped": 1
    };
    compare(JSON.stringify(HyprLua.configTable(fieldSchema, values, hex)), JSON.stringify({
      "general": {
        "layout": "dwindle"
      }
    }));
  }

  function test_changed_fields_convert() {
    const table = HyprLua.configTable(fieldSchema, {
      "gaps": 8,
      "both": 2,
      "opacity": 90,
      "flag": true,
      "border": "base08",
      "always": "master",
      "gated": 3,
      "blur": true
    }, hex, {
      "general.gaps_out": 12
    });
    compare(table.general.gaps_in, 8);
    compare(table.general.gaps_out, 12);
    compare(table.a.one, 2);
    compare(table.a.two, 2);
    compare(table.decoration.active_opacity, 0.9);
    compare(table.misc.flag, 1);
    compare(table.general.col.active_border, "rgba(445566cc)");
    compare(table.general.layout, "master");
    // x-hyprIf: written, default or not, only while the switch is on
    compare(table.blur.size, 3);
  }

  function test_serialize_is_sorted_and_nested() {
    compare(HyprLua.serialize({}), "{}");
    compare(HyprLua.serialize({
      "b": 1,
      "a": {
        "y": "s",
        "x": true
      }
    }), '{\n  a = { x = true, y = "s" },\n  b = 1,\n}');
  }

  // Every managed option, each changed from its default, as Lua
  function test_managed_schema_serializes_to_lua() {
    const schema = files.json("config/json/config.schema.json");
    const managed = schema.properties.Hyprland.properties.managed;
    const values = SchemaValidation.applyDefaults({}, managed, schema);
    const expected = [];
    for (const key in managed.properties) {
      const field = managed.properties[key];
      if (!field["x-hypr"])
        continue;
      if (field["x-hyprIf"])
        values[field["x-hyprIf"]] = true;
      if (field.type === "boolean")
        values[key] = !values[key];
      else if (field.type === "integer")
        values[key] = values[key] + 1 <= (field.maximum ?? Infinity) ? values[key] + 1 : values[key] - 1;
      else if (field.enum)
        values[key] = field.enum.find(option => option !== values[key]);
      else if (field.type === "string")
        values[key] = field["x-hyprValue"] === "color" ? "base08" : "changed";
      expected.push(...(typeof field["x-hypr"] === "string" ? [field["x-hypr"]] : field["x-hypr"]));
    }
    const table = HyprLua.configTable(managed, values, hex);
    for (const path of expected) {
      let node = table;
      for (const key of path.split("."))
        node = node?.[key];
      verify(node !== undefined, path + " missing from the table");
    }
    const lua = "hl = { config = function(t) end }\nhl.config(" + HyprLua.serialize(table) + ")\n";
    const written = files.write("tests/.out/managed.lua", lua);
    tryVerify(() => written.done, 2000);
  }
}
