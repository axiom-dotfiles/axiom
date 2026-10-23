package config

import (
	"github.com/axiom-shell/axiom/backend/internal/axerr"
	"github.com/axiom-shell/axiom/backend/internal/jsonx"
	"github.com/axiom-shell/axiom/backend/internal/schema"
)

// Pipeline is what the config store does to a file it reads and to a
// config it is asked to write, for one config format.
type Pipeline interface {
	// Load brings a parsed config.json to the current shape: migrated,
	// pruned of unknown keys, filled with defaults and validated (Errors
	// non-empty when invalid). Migrated says it changed shape, so it is
	// written back (Loaded.Migrated).
	Load(parsed any) (Loaded, error)
	// Check fills defaults into a config about to be written and returns
	// it, or the reasons it's invalid. Unknown keys are errors here: a
	// write never silently drops what it was asked to write.
	Check(cfg *jsonx.Object) (*jsonx.Object, []string)
	// Defaults is the config of an empty file.
	Defaults() *jsonx.Object
	// Schema is the schema the pipeline validates against.
	Schema() *schema.Schema
}

// LegacyPipeline is format 1 (versions 1 to 75): until config v2, what
// the shell did, against the tree's (v75) schema.
type LegacyPipeline struct {
	S *schema.Schema
}

func (p LegacyPipeline) Schema() *schema.Schema { return p.S }

func (p LegacyPipeline) Load(parsed any) (Loaded, error) {
	if _, ok := parsed.(*jsonx.Object); !ok {
		return Loaded{}, axerr.New(axerr.InvalidConfig, "config.json must hold an object")
	}
	return LoadLegacy(p.S, parsed)
}

func (p LegacyPipeline) Check(cfg *jsonx.Object) (*jsonx.Object, []string) {
	filled, _ := ApplyDefaults(p.S, cfg, true, p.S.Root())
	obj, _ := filled.(*jsonx.Object)
	if errs := ValidationErrors(p.S, obj, p.S.Root()); len(errs) > 0 {
		return nil, errs
	}
	return obj, nil
}

func (p LegacyPipeline) Defaults() *jsonx.Object {
	filled, _ := ApplyDefaults(p.S, jsonx.NewObject(), true, p.S.Root())
	return filled.(*jsonx.Object)
}
