package config

import (
	"github.com/axiom-shell/axiom/backend/internal/jsonx"
	"github.com/axiom-shell/axiom/backend/internal/migrate/legacy"
	"github.com/axiom-shell/axiom/backend/internal/schema"
)

// Loaded is a parsed config.json after the whole load: migrated, pruned,
// filled with defaults and validated.
type Loaded struct {
	Config  *jsonx.Object
	Removed []string // unknown keys dropped (logged as warnings)
	Changes []string // what the migrations did (logged)
	Secrets *jsonx.Object
	Errors  []string // why it is invalid; empty when it is valid
	// Migrated says the file was of an older version (written back once)
	Migrated bool
}

// LoadLegacy runs what the shell's ConfigManager did with a parsed
// format-1 config.json: migrate to v75, prune unknown keys, fill defaults,
// validate, all against s (the v75 schema).
func LoadLegacy(s *schema.Schema, parsed any) (Loaded, error) {
	migration, err := legacy.Migrate(parsed)
	if err != nil {
		return Loaded{}, err
	}
	removed := Prune(s, migration.Config, s.Root())
	filled, _ := ApplyDefaults(s, migration.Config, true, s.Root())
	obj, _ := filled.(*jsonx.Object)
	return Loaded{
		Config:   obj,
		Removed:  removed,
		Changes:  migration.Changes,
		Secrets:  migration.Secrets,
		Errors:   ValidationErrors(s, filled, s.Root()),
		Migrated: migration.Migrated,
	}, nil
}

// Object is l as the shared fixtures write it.
func (l Loaded) Object() *jsonx.Object {
	return jsonx.Obj(
		"config", l.Config,
		"removed", stringsArray(l.Removed),
		"changes", stringsArray(l.Changes),
		"secrets", l.Secrets,
		"errors", stringsArray(l.Errors),
	)
}

func stringsArray(list []string) *jsonx.Array {
	a := jsonx.Arr()
	for _, s := range list {
		a.Append(s)
	}
	return a
}
