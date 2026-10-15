# Recipe: a config migration step

> **Use when:** renaming, moving, reshaping or re-defaulting a key that existing configs already have. A purely additive key needs no migration ([setting](setting.md)).
> **Copy from:** `components/methods/ConfigMigration.qml` → `_v52ToV53` (rename with `_eachWidget` + `_renameKey`), `_v45ToV46` (append a tool page once), `_v47ToV48` (change an old default); test `test_v53_time_calendar_switch_is_its_popout` in `tests/tst_Config.qml`
> **Docs:** [config-manager](../dev/core/config-manager.md) (load pipeline), `components/methods/AGENTS.md`

## Files to touch, in this order
1. `config/json/config.schema.json`:
   - the new shape first;
   - `properties.version.default` → N.
2. `components/methods/ConfigMigration.qml`:
   - `currentVersion: N`;
   - `if (version < N) result = _vMToVN(result, changes);` at the end of `migrate()`;
   - the `_vMToVN` function at the end of the file, with a comment saying what vN changed and why.
3. `tests/tst_Config.qml`: a `test_vN_<what>` case.
4. Readers and consumers of the changed keys.

## Skeleton
```qml
  // vN renamed the Foo widget's oldKey to newKey, as on the other widgets
  function _vMToVN(config, changes) {
    root._eachWidget(config, (widget, where) => {
      if (widget.type === "Foo" && widget.properties && typeof widget.properties === "object")
        root._renameKey(widget.properties, "oldKey", "newKey", `${where}.properties`, changes);
    });
    return config;
  }
```
```qml
  function test_vN_foo_old_key_is_new_key() {
    const migrated = load({
      "version": M,
      "Bars": [{ "id": "main", "widgets": { "left": [{ "type": "Foo", "properties": { "oldKey": true } }] } }]
    });
    const widget = migrated.config.Bars[0].widgets.left[0];
    compare(widget.properties.newKey, true);
    compare(widget.properties.oldKey, undefined);
    compare(migrated.removed, []);
    compare(errors(migrated.config), []);
  }
```

## Steps
1. **Schema first, in one go:** the new shape and the `version` default. If the migration is saved first, the live shell hot-reloads, migrates against the old schema, writes `config.json` back at the new version and prunes the new keys, and the user's values are lost.
2. **Bump `currentVersion`** to the same N. `test_version_matches_schema` enforces it.
3. **Add the step call and the function.** The step must:
   - **Be idempotent:** a config already in the new shape passes through unchanged (`test_migration_is_idempotent`).
   - **Guard odd input:** missing sections, non-objects, non-arrays (`typeof … === "object"`, `Array.isArray`).
   - **Edit in place:** `migrate()` deep-clones the config once at the top, so a step may edit `config` in place and return it, as `_v45ToV46` does.
   - **Report its changes:** push a short English line onto `changes` per change (logs stay English).
4. **Add the test.** It uses the file's `load(parsed)` (migrate → prune → defaults, as `ConfigManager` does) and `errors(config)`. Assert:
   - the new values;
   - that the old key is gone;
   - `migrated.removed` is `[]`;
   - `errors(migrated.config)` is `[]`.
5. **Update the readers and consumers** of the changed keys.

## Gotchas
- **Modules:** `_eachModule(config, fn(module, where))` covers every layout's modules (overlay pages, edge menus, the lock and login screens, the desktops), as `_v53ToV54` uses it.
- **Other helpers:** `_eachWidget(config, fn(widget, where))` covers every bar's widget sections, and `_addBinds(config, changes, added)` adds Hyprland binds.
- **The fixtures already cover this:** `tests/fixtures/configs/v1.json` and `v30.json` run through every step. A broken new step usually shows up there too. A new fixture is only worth it for a large reshape.
- **Shipped examples:** `examples/*.json` are at an older version and migrate on load (`tst_ConfigExamples`). Check they still pass.
- **Version numbers:** never renumber existing steps or reuse a version.
- **Secrets** found in an old config go into the `secrets` map `migrate()` returns (ConfigManager hands them to `SecretsManager`), never back into the config.

## Verify
- `scripts/run_tests.sh Config ConfigExamples`
- `scripts/dev/verify.sh`
- Then check `scripts/log.sh`: the live config migrates once on reload and logs its `changes`. Confirm the user's values survived in `~/.config/axiom/config.json`.

## Docs to update
- The doc of the feature whose keys moved (`docs/dev/…`). Old names live only in git history and the migration's comment.
- `docs/configuration.md` if users edit the moved key by hand.
