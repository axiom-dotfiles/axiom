import QtQuick
import QtTest
import Qt.labs.folderlistmodel
import qs.components.methods

// ConfigExamples (what an example setup holds and how it applies), and the
// shipped examples/*.json: each loads as a valid config the way
// SavedConfigsManager loads it, so an example can't rot when the schema moves.
TestCase {
  name: "ConfigExamples"

  RepoFiles {
    id: files
  }

  FolderListModel {
    id: examples
    folder: files.url("examples/")
    nameFilters: ["*.json"]
    showDirs: false
  }

  property var schema

  function initTestCase() {
    schema = files.json("config/json/config.schema.json");
  }

  // ConfigManager.normalizeConfig: migrate → prune → defaults
  function load(parsed) {
    const config = ConfigMigration.migrate(parsed).config;
    SchemaValidation.pruneUnknown(config, schema);
    return SchemaValidation.applyDefaults(config, schema);
  }

  function test_pick_takes_listed_parts_only() {
    const picked = ConfigExamples.pick({
      "Appearance": {
        "theme": "dracula",
        "wallpaper": "/some/where.png"
      },
      "Bars": [
        {
          "id": "top"
        }
      ],
      "Calendar": {
        "accounts": []
      }
    });
    compare(picked, {
      "Appearance": {
        "theme": "dracula"
      },
      "Bars": [
        {
          "id": "top"
        }
      ]
    });
  }

  function test_apply_replaces_parts_and_keeps_the_rest() {
    const current = {
      "Appearance": {
        "theme": "nord",
        "wallpaper": "/mine.png"
      },
      "EdgeMenus": [
        {
          "id": "old"
        },
        {
          "id": "older"
        }
      ],
      "Chat": {
        "providers": ["mine"]
      }
    };
    const result = ConfigExamples.apply(current, {
      "Appearance": {
        "theme": "dracula",
        "wallpaper": "/theirs.png"
      },
      "EdgeMenus": [
        {
          "id": "new"
        }
      ],
      "Chat": {
        "providers": []
      }
    });
    compare(result.Appearance, {
      "theme": "dracula",
      "wallpaper": "/mine.png"
    });
    compare(result.EdgeMenus, [
      {
        "id": "new"
      }
    ]);
    compare(result.Chat.providers, ["mine"]);
    // The input is left as it was
    compare(current.Appearance.theme, "nord");
  }

  function test_examples_exist() {
    tryVerify(() => examples.status === FolderListModel.Ready && examples.count > 0);
  }

  function test_examples_are_valid() {
    tryVerify(() => examples.status === FolderListModel.Ready && examples.count > 0);
    for (let i = 0; i < examples.count; i++) {
      const name = examples.get(i, "fileName");
      const example = files.json("examples/" + name);
      verify(example._example?.title, name + " has a title");
      const errors = SchemaValidation.validationErrors(load(example), schema);
      compare(errors, [], name);
      // Applied onto the defaults, it is still a valid config
      const applied = ConfigExamples.apply(load({}), load(example));
      compare(SchemaValidation.validationErrors(applied, schema), [], name + " applied");
      for (const section in example) {
        if (section !== "_example" && section !== "version")
          verify(ConfigExamples.sections[section] !== undefined, name + ": " + section + " is not a part examples hold");
      }
    }
  }
}
