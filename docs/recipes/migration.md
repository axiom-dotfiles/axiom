# Recipe: a config migration step

> **Use when:** renaming, moving, reshaping or re-defaulting a key that existing configs already have. A purely additive key needs no migration ([setting](setting.md)).
> **Docs:** [the axiom binary](../dev/backend/README.md), [config-manager](../dev/core/config-manager.md) (load pipeline)

The format-1 migrations (versions 1 to 75) are **frozen**: `components/methods/ConfigMigration.qml` is the record of what they did, and the axiom binary runs a copy of it (`backend/internal/migrate/legacy/legacy.js`) on configs from before it took the config over. Neither file ever changes; the shared fixtures (`tests/fixtures/shared/legacy/`) check that they still agree.

A reshape of existing config is a config v2 migration step, written in Go in the binary. That pipeline is being built on this branch: until it lands, reshape nothing and add the new key alongside the old instead ([setting](setting.md)).
