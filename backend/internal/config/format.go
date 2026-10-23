package config

import (
	"fmt"

	"github.com/axiom-shell/axiom/backend/internal/axerr"
	"github.com/axiom-shell/axiom/backend/internal/jsonx"
	"github.com/axiom-shell/axiom/backend/internal/migrate/convert"
	"github.com/axiom-shell/axiom/backend/internal/migrate/legacy"
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

// V2Pipeline is format 2 (docs/dev/core/config-v2.md), against the tree's
// schema. It reads format 1 too: such a file goes through the frozen
// migrations to version 75 (against the frozen v75 schema), is converted,
// then loads as format 2 (Loaded.FromFormat1).
type V2Pipeline struct {
	S *schema.Schema
}

func (p V2Pipeline) Schema() *schema.Schema { return p.S }

func (p V2Pipeline) Load(parsed any) (Loaded, error) {
	obj, ok := parsed.(*jsonx.Object)
	if !ok {
		return Loaded{}, axerr.New(axerr.InvalidConfig, "config.json must hold an object")
	}
	version, _ := obj.Value("version").(float64)
	format, hasFormat := obj.Get("format")
	switch {
	case !hasFormat && version > legacy.LastVersion:
		// Format 2's numbers in a file without a format: an older shell
		// (format 1 only) rewrote it, dropping the keys it didn't know
		return Loaded{Config: obj, Errors: []string{fmt.Sprintf(
			"version: %v without a format: an older axiom rewrote this format-2 config (config.format1.json holds the file from before the conversion)", version)}}, nil
	case !hasFormat:
		old, err := LoadLegacy(schema.New(legacy.Schema()), obj)
		if err != nil {
			return Loaded{}, err
		}
		if len(old.Errors) > 0 {
			// Invalid as format 1: left as it is until it's fixed
			return old, nil
		}
		converted := convert.ToV2(old.Config)
		l := p.normalize(converted.Config)
		l.Changes = append(old.Changes, converted.Changes...)
		l.Secrets = old.Secrets
		l.Migrated, l.FromFormat1 = true, true
		return l, nil
	case format != float64(convert.Format):
		return Loaded{Config: obj, Errors: []string{fmt.Sprintf("format: %v isn't one this axiom reads (it reads 1 and %d)", format, convert.Format)}}, nil
	case version > convert.Version:
		return Loaded{Config: obj, Errors: []string{fmt.Sprintf("version: %v is newer than this axiom knows (%d): update axiom", version, convert.Version)}}, nil
	}
	return p.normalize(obj), nil
}

// normalize prunes unknown keys, fills defaults and validates.
func (p V2Pipeline) normalize(cfg *jsonx.Object) Loaded {
	removed := Prune(p.S, cfg, p.S.Root())
	filled, _ := ApplyDefaults(p.S, cfg, true, p.S.Root())
	obj, _ := filled.(*jsonx.Object)
	return Loaded{Config: obj, Removed: removed, Errors: ValidationErrors(p.S, filled, p.S.Root())}
}

func (p V2Pipeline) Check(cfg *jsonx.Object) (*jsonx.Object, []string) {
	filled, _ := ApplyDefaults(p.S, cfg, true, p.S.Root())
	obj, _ := filled.(*jsonx.Object)
	if errs := ValidationErrors(p.S, obj, p.S.Root()); len(errs) > 0 {
		return nil, errs
	}
	return obj, nil
}

func (p V2Pipeline) Defaults() *jsonx.Object {
	filled, _ := ApplyDefaults(p.S, jsonx.NewObject(), true, p.S.Root())
	return filled.(*jsonx.Object)
}
