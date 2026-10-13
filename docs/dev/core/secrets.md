# Secrets

> **Files:** `services/SecretsManager.qml`, `components/views/settings/ChatProvidersCard.qml`, `components/views/settings/CalendarAccountsCard.qml`
> **Config:** none (secrets never go in config.json); a provider's `keyEnv`
> **Related:** [Chat](../features/chat.md), [Calendar](../features/calendar.md), [Config manager](config-manager.md)

Where API keys and passwords live. (Rule: AGENTS.md › Services, "Secrets".)

### Scopes
- `provider`: chat API keys.
- `calendar`: calendar account passwords.

### Lookup order
1. A provider's `keyEnv` environment variable.
2. The keyring (`secret-tool`, `service axiom <scope> <id>`; probed once, `keyringAvailable`).
3. `$XDG_STATE_HOME/axiom/secrets.json` (mode 600). A provider's key sits under its bare id (as before scopes existed); any other under `<scope>:<id>`.

### API
- `withSecret(scope, id, cb)`: async, cached per session.
- `secretStatus(scope, id)`: `keyring` | `file` | `none` ("" while looked up).
- `setSecret` / `clearSecret`: write through stdin, never argv.
- `refreshSecrets(scope, ids)`: for a card showing them.
- Provider wrappers: `withKey`, `status` (adds `env` | `unneeded`), `setKey`, `clearKey`, `refresh`.

### Where they're entered
- Keys: `views/settings/ChatProvidersCard` (the Chat section's `x-card`, with Test and Fetch models).
- Passwords: `CalendarAccountsCard`.
- Never through the settings draft.
- `ConfigMigration` moves API keys found in config.json to SecretsManager.
