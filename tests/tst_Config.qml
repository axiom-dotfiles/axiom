import QtQuick
import QtTest
import qs.components.methods

// The real schema and ConfigMigration together: the defaults are a valid
// config, every oneOf variant's defaults are valid, and old configs load
// the way ConfigManager loads them (migrate → prune → defaults → validate).
TestCase {
  name: "Config"

  RepoFiles {
    id: files
  }

  property var schema

  function initTestCase() {
    schema = files.json("config/json/config.schema.json");
  }

  function errors(value, subSchema) {
    return SchemaValidation.validationErrors(value, subSchema ?? schema);
  }

  // What ConfigManager does with a parsed config.json
  function load(parsed) {
    const migration = ConfigMigration.migrate(parsed);
    const config = migration.config;
    const removed = SchemaValidation.pruneUnknown(config, schema);
    return {
      config: SchemaValidation.applyDefaults(config, schema),
      removed: removed,
      changes: migration.changes
    };
  }

  function test_version_matches_schema() {
    compare(ConfigMigration.currentVersion, schema.properties.version.default);
  }

  function test_defaults_are_valid() {
    compare(errors(SchemaValidation.applyDefaults({}, schema)), []);
  }

  function test_empty_config_loads() {
    const loaded = load({});
    compare(errors(loaded.config), []);
    compare(loaded.config.version, ConfigMigration.currentVersion);
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
    const filled = SchemaValidation.applyDefaults({
      "type": data.type
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

  function test_v1_config_migrates_to_a_valid_one() {
    const loaded = load(files.json("tests/fixtures/configs/v1.json"));
    const config = loaded.config;
    compare(errors(config), []);
    compare(loaded.removed, []);
    compare(config.version, ConfigMigration.currentVersion);

    // v2 + v8: the old Workspaces widget was the grid, now the grid layout
    const left = config.Bars[0].widgets.left;
    compare(left[0].type, "Workspaces");
    compare(left[0].properties.textColor, "base0D");
    compare(config.Workspaces.layout, "grid");
    // v3: the bar's inset keeps its widgets 26 px high
    compare(config.Bars[0].inset, 4);
    // v4, v6
    compare(config.Appearance.autoThemeSwitch, undefined);
    compare(config.General.monitors, "focused");
    // v9: an old default glyph becomes its Material Symbols name
    compare(left[1].properties.icon, "apps");
    // v10: the grid popout's icons move onto the widget
    compare(config.Popouts.workspaceIcons, undefined);
    compare(left[0].properties.showAppIcons, true);
    // v5, v7, v13: the pages that became views
    const types = config.Overlay.views.map(view => view.type);
    compare(types[0], "Settings");
    verify(types.includes("Themes"));
    verify(types.includes("EdgeMenuEditor"));
    // v11: backends become providers, keeping a model the user added
    compare(config.Chat.defaultProvider, "anthropic");
    const anthropic = config.Chat.providers.find(p => p.id === "anthropic");
    verify(anthropic.models.includes("my-own-model"));
    // v12: QuickToggles and Session become QuickActions
    const cells = config.Overlay.views[1].columns[0].cells;
    compare(cells[0].slots.main.type, "QuickActions");
    compare(cells[1].slots.main.properties.actions, ["lock", "reboot"]);
  }

  function test_migration_is_idempotent() {
    const once = load(files.json("tests/fixtures/configs/v1.json")).config;
    const again = ConfigMigration.migrate(once);
    compare(again.migrated, false);
    compare(again.changes, []);
    compare(JSON.stringify(again.config), JSON.stringify(once));
  }

  function test_migrate_does_not_modify_its_input() {
    const input = files.json("tests/fixtures/configs/v1.json");
    const before = JSON.stringify(input);
    ConfigMigration.migrate(input);
    compare(JSON.stringify(input), before);
  }

  function test_newer_version_is_kept() {
    const result = ConfigMigration.migrate({
      "version": ConfigMigration.currentVersion + 1
    });
    compare(result.config.version, ConfigMigration.currentVersion + 1);
    compare(result.migrated, false);
  }
}
