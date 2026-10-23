package config

import (
	"reflect"
	"sort"
	"testing"

	"github.com/axiom-shell/axiom/backend/internal/jsonx"
	"github.com/axiom-shell/axiom/backend/internal/schema"
)

func mustParse(t *testing.T, text string) any {
	t.Helper()
	v, err := jsonx.Unmarshal([]byte(text))
	if err != nil {
		t.Fatal(err)
	}
	return v
}

// Prune drops, in place, every key the schema doesn't know (through
// $refs, oneOf options and a $ref's sibling keys), keeping what
// additionalProperties allows, and says which it dropped.
func TestPrune(t *testing.T) {
	t.Parallel()
	root := mustParse(t, `{"type": "object", "additionalProperties": false,
		"properties": {
			"size": {"type": "integer", "default": 10},
			"nested": {"type": "object", "additionalProperties": false, "properties": {"on": {"type": "boolean", "default": true}}},
			"widgets": {"type": "array", "default": [], "items": {"$ref": "#/definitions/Widget"}},
			"free": {"type": "object", "additionalProperties": {"type": "integer"}},
			"a": {"$ref": "#/definitions/Box", "default": {"items": ["a"]}}
		},
		"definitions": {
			"Widget": {"oneOf": [{"$ref": "#/definitions/Clock"}, {"$ref": "#/definitions/Label"}]},
			"Clock": {"type": "object", "additionalProperties": false, "required": ["type"], "properties": {"type": {"const": "Clock"}, "format": {"type": "string", "default": "HH:mm"}}},
			"Label": {"type": "object", "additionalProperties": false, "required": ["type", "text"], "properties": {"type": {"const": "Label"}, "text": {"type": "string"}}},
			"Box": {"type": "object", "additionalProperties": false, "properties": {"size": {"type": "integer", "default": 2}, "items": {"type": "array", "default": [], "items": {"type": "string"}}}}
		}}`)
	s := schema.New(root)
	for _, tc := range []struct {
		name, value, after string
		removed            []string
	}{
		{"unknown keys", `{"size": 2, "stray": true, "nested": {"on": true, "old": 1}, "widgets": [{"type": "Clock", "gone": 1}], "free": {"kept": 1}}`,
			`{"size":2,"nested":{"on":true},"widgets":[{"type":"Clock"}],"free":{"kept":1}}`, []string{"nested.old", "stray", "widgets[0].gone"}},
		{"through a ref with siblings", `{"a": {"size": 1, "gone": true}}`, `{"a":{"size":1}}`, []string{"a.gone"}},
		{"nothing to drop", `{"size": 3, "widgets": [{"type": "Label", "text": "x"}]}`, `{"size":3,"widgets":[{"type":"Label","text":"x"}]}`, nil},
	} {
		t.Run(tc.name, func(t *testing.T) {
			t.Parallel()
			value := mustParse(t, tc.value)
			removed := Prune(s, value, root)
			sort.Strings(removed)
			if len(removed) == 0 {
				removed = nil
			}
			if !reflect.DeepEqual(removed, tc.removed) {
				t.Errorf("removed %v, want %v", removed, tc.removed)
			}
			if got := string(jsonx.MarshalCompact(value)); got != tc.after {
				t.Errorf("after %s, want %s", got, tc.after)
			}
			if errs := ValidationErrors(s, value, root); len(errs) > 0 {
				t.Errorf("invalid after pruning: %v", errs)
			}
		})
	}
}
