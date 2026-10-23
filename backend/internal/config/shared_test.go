package config

import (
	"testing"

	"github.com/axiom-shell/axiom/backend/internal/jsonx"
	"github.com/axiom-shell/axiom/backend/internal/schema"
	"github.com/axiom-shell/axiom/backend/internal/testkit"
)

// The schema.* shared cases (recorded from SchemaValidation.qml) replayed
// through the Go pipeline: each output must be the JS bytes exactly.
func TestSharedSchemaCases(t *testing.T) {
	t.Parallel()
	for _, c := range testkit.Cases(t, "schema.") {
		t.Run(c.Name, func(t *testing.T) {
			c.Compare(t, runSchemaOp(t, c))
		})
	}
}

func runSchemaOp(t *testing.T, c testkit.Case) any {
	t.Helper()
	switch c.Op {
	case "schema.applyDefaults":
		root := c.Args[1]
		if len(c.Args) > 2 {
			root = c.Args[2]
		}
		out, ok := ApplyDefaults(schema.New(root), c.Args[0], true, c.Args[1])
		if !ok {
			return nil
		}
		return out
	case "schema.pruneUnknown":
		removed := Prune(schema.New(c.Args[1]), c.Args[0], c.Args[1])
		return jsonx.Obj("value", c.Args[0], "removed", stringArray(removed))
	case "schema.validationErrors":
		return stringArray(ValidationErrors(schema.New(c.Args[1]), c.Args[0], c.Args[1]))
	case "schema.resolveRef":
		return schema.New(c.Args[1]).Resolve(c.Args[0])
	}
	t.Fatalf("unknown op %s", c.Op)
	return nil
}

func stringArray(list []string) *jsonx.Array {
	a := jsonx.Arr()
	for _, s := range list {
		a.Append(s)
	}
	return a
}

// The corpus: every past schema version's defaults and the old configs,
// loaded whole, must come out as the shell's ConfigManager made them.
func TestSharedLoadCases(t *testing.T) {
	t.Parallel()
	for _, c := range testkit.Cases(t, "legacy.load") {
		t.Run(c.Name, func(t *testing.T) {
			t.Parallel()
			loaded, err := LoadLegacy(schema.New(c.Args[1]), c.Args[0])
			if err != nil {
				t.Fatal(err)
			}
			c.Compare(t, loaded.Object())
		})
	}
}
