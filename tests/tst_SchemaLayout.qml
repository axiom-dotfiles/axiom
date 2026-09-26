import QtQuick
import QtTest
import qs.components.methods

TestCase {
  name: "SchemaLayout"

  RepoFiles {
    id: files
  }

  property var schema

  function initTestCase() {
    schema = files.json("config/json/config.schema.json");
  }

  function test_rows_flatten_and_skip_hidden() {
    const rows = SchemaLayout.rows({
      "properties": {
        "a": {
          "type": "string",
          "title": "A"
        },
        "hidden": {
          "type": "string",
          "x-settings": false
        },
        "group": {
          "type": "object",
          "properties": {
            "b": {
              "type": "boolean"
            }
          }
        },
        "empty": {
          "type": "object",
          "properties": {}
        },
        "list": {
          "type": "array",
          "items": {
            "properties": {
              "x": {
                "type": "string"
              }
            }
          }
        },
        "tags": {
          "type": "array",
          "items": {
            "type": "string"
          }
        }
      }
    }, ["S"]);
    compare(rows.map(r => r.kind + ":" + r.path.join(".")), ["field:S.a", "group:S.group", "field:S.group.b", "array:S.list", "field:S.tags"]);
  }

  function test_showIfHolds() {
    const values = {
      "mode": "grid",
      "on": true
    };
    const valueOf = key => values[key];
    verify(SchemaLayout.showIfHolds(null, valueOf));
    verify(SchemaLayout.showIfHolds({
      "mode": "grid"
    }, valueOf));
    verify(!SchemaLayout.showIfHolds({
      "mode": "standard"
    }, valueOf));
    verify(SchemaLayout.showIfHolds({
      "mode": ["standard", "grid"]
    }, valueOf));
    verify(!SchemaLayout.showIfHolds({
      "mode": {
        "not": "grid"
      }
    }, valueOf));
    verify(!SchemaLayout.showIfHolds({
      "mode": "grid",
      "on": false
    }, valueOf));
  }

  // The real settings page: every category has cards, and every
  // `x-showIf` names a sibling or a config path that exists
  function test_real_schema_categories() {
    const categories = SchemaLayout.categories(schema);
    verify(categories.length > 3);
    for (const category of categories) {
      verify(category.sections.length > 0, category.name);
      for (const key of category.sections)
        verify(SchemaLayout.groups(schema, key).length > 0, key);
    }
    verify(!categories.some(c => c.sections.includes("Bars")), "Bars is edited by the bar editor");
  }

  function test_real_schema_showIf_targets_exist() {
    const bad = [];
    const visit = (node, siblings, where) => {
      if (!node || typeof node !== "object")
        return;
      if (node.$ref)
        return;
      for (const key in node.properties ?? {}) {
        const prop = node.properties[key];
        for (const target in prop["x-showIf"] ?? {}) {
          if (target.startsWith("/")) {
            const path = target.slice(1).split(".");
            let s = schema;
            for (const part of path)
              s = s?.properties?.[part];
            if (!s)
              bad.push(`${where}.${key}: ${target}`);
          } else if (!(target in node.properties)) {
            bad.push(`${where}.${key}: ${target}`);
          }
        }
        visit(prop, node.properties, `${where}.${key}`);
        visit(prop.items, null, `${where}.${key}[]`);
      }
    };
    visit(schema, null, "");
    for (const name in schema.definitions)
      visit(schema.definitions[name], null, name);
    compare(bad, []);
  }
}
