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
      "on": true,
      "list": [1],
      "none": []
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
    // notEmpty: a list with something in it
    verify(SchemaLayout.showIfHolds({
      "list": {
        "notEmpty": true
      }
    }, valueOf));
    verify(!SchemaLayout.showIfHolds({
      "none": {
        "notEmpty": true
      }
    }, valueOf));
    // anyOf: one of its conditions holds, alongside the other keys
    verify(SchemaLayout.showIfHolds({
      "anyOf": [
        {
          "mode": "standard"
        },
        {
          "mode": "grid",
          "on": true
        }
      ]
    }, valueOf));
    verify(!SchemaLayout.showIfHolds({
      "anyOf": [
        {
          "mode": "standard"
        },
        {
          "on": false
        }
      ]
    }, valueOf));
    verify(!SchemaLayout.showIfHolds({
      "on": false,
      "anyOf": [
        {
          "mode": "grid"
        }
      ]
    }, valueOf));
  }

  // The real settings page: every category has cards, and every
  // `x-showIf` names a sibling or a config path that exists
  function test_intro_on_the_sections_own_card() {
    const groups = SchemaLayout.groups({
      "properties": {
        "S": {
          "type": "object",
          "title": "Sec",
          "x-intro": "Status",
          "properties": {
            "a": {
              "type": "boolean",
              "title": "A"
            },
            "b": {
              "type": "boolean",
              "title": "B",
              "x-group": "Other"
            }
          }
        }
      }
    }, "S");
    compare(groups.length, 2, "no separate card");
    compare(groups[0].title, "Sec");
    compare(groups[0].intro, "Status");
    compare(groups[1].intro, "");
  }

  // A hand-built card goes first; with `x-cardFolds` it folds, and the
  // real cards that fold take their key as `foldKey` (EntryListCards do)
  function test_card_folds() {
    const groups = SchemaLayout.groups({
      "properties": {
        "S": {
          "type": "object",
          "x-card": "List",
          "x-cardFolds": true,
          "properties": {}
        }
      }
    }, "S");
    compare(groups[0].kind, "card");
    compare(groups[0].key, "S:List");
    verify(groups[0].folds);
    for (const key in schema.properties) {
      const section = schema.properties[key];
      if (section["x-cardFolds"])
        verify(/^EntryListCard \{|property string foldKey/m.test(files.text("components/views/settings/" + section["x-card"] + "Card.qml")), key);
    }
  }

  function test_objectGroups() {
    const groups = SchemaLayout.objectGroups({
      "x-order": ["b", "a"],
      "properties": {
        "a": {
          "x-group": "One"
        },
        "b": {
          "x-group": "Two"
        },
        "c": {},
        "skip": {
          "x-group": "One"
        },
        "hidden": {
          "x-group": "One",
          "x-settings": false
        }
      }
    }, ["skip"]);
    compare(groups.map(g => g.title + ":" + g.keys.join(",")), ["Two:b", "One:a", "Other:c"]);
    compare(Object.keys(groups[1].schema), ["a"]);
    const bar = SchemaLayout.objectGroups(schema.definitions.Bar, ["widgets"]);
    compare(bar.map(g => g.title), ["General", "Size", "Style", "Widgets", "Accents", "Shadow", "Behaviour"]);
    const menu = SchemaLayout.objectGroups(schema.definitions.EdgeMenu, ["modules"]);
    compare(menu.map(g => g.title), ["General", "Opening", "Placement", "Style", "Closing", "Advanced"]);
  }

  function test_real_schema_intros_exist() {
    for (const key in schema.properties) {
      const intro = schema.properties[key]["x-intro"];
      if (intro)
        verify(files.text("components/views/settings/" + intro + ".qml").includes("x-intro"), intro);
    }
  }

  // `x-categories` orders them and names their icon and page; others
  // follow in schema order; an empty declared one is left out unless it
  // has a page
  function test_categories_order_icon_page() {
    const field = {
      "type": "string",
      "default": ""
    };
    const categories = SchemaLayout.categories({
      "x-categories": [
        {
          "name": "B",
          "icon": "star"
        },
        {
          "name": "Empty"
        },
        {
          "name": "Tools",
          "icon": "build",
          "page": "ToolsPage"
        }
      ],
      "properties": {
        "One": {
          "type": "object",
          "x-category": "A",
          "properties": {
            "f": field
          }
        },
        "Two": {
          "type": "object",
          "x-category": "B",
          "x-links": ["Themes"],
          "properties": {
            "f": field
          }
        },
        "Three": {
          "type": "object",
          "title": "Three",
          "properties": {
            "f": field
          }
        }
      }
    });
    compare(categories.map(c => c.name), ["B", "Tools", "A", "Three"]);
    compare(categories[0].icon, "star");
    compare(categories[0].sections, ["Two"]);
    compare(categories[0].links, ["Themes"]);
    compare(categories[1].page, "ToolsPage");
    compare(categories[1].sections, []);
    compare(categories[2].icon, "settings");
    compare(categories[2].page, "");
  }

  function test_real_schema_categories() {
    const categories = SchemaLayout.categories(schema);
    verify(categories.length > 3);
    const declared = schema["x-categories"].map(c => c.name);
    for (const category of categories) {
      verify(declared.includes(category.name), "declared in x-categories: " + category.name);
      if (category.page !== "") {
        verify(files.text("components/views/settings/" + category.page + ".qml").length > 0, category.page);
        continue;
      }
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
        const condition = prop["x-showIf"] ?? {};
        const targets = [].concat(Object.keys(condition).filter(target => target !== "anyOf"), ...(condition.anyOf ?? []).map(any => Object.keys(any)));
        for (const target of targets) {
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
