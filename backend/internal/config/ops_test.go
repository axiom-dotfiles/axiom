package config

import (
	"encoding/json"
	"testing"

	"github.com/axiom-shell/axiom/backend/internal/axerr"
	"github.com/axiom-shell/axiom/backend/internal/jsonx"
)

func parseOps(t *testing.T, text string) []Op {
	t.Helper()
	var ops []Op
	if err := json.Unmarshal([]byte(text), &ops); err != nil {
		t.Fatal(err)
	}
	return ops
}

func cfg(t *testing.T, text string) *jsonx.Object {
	t.Helper()
	v, err := jsonx.Unmarshal([]byte(text))
	if err != nil {
		t.Fatal(err)
	}
	return v.(*jsonx.Object)
}

func TestOps(t *testing.T) {
	t.Parallel()
	cases := []struct {
		name, config, ops, want string
		kind                    axerr.Kind
	}{
		{"set makes objects", `{}`, `[{"op":"set","path":["A","b"],"value":1}]`, `{"A":{"b":1}}`, ""},
		{"set by id", `{"L":[{"id":"x","v":1},{"id":"y","v":2}]}`, `[{"op":"set","path":["L",{"id":"y"},"v"],"value":3}]`, `{"L":[{"id":"x","v":1},{"id":"y","v":3}]}`, ""},
		{"delete by id", `{"L":[{"id":"x"},{"id":"y"}]}`, `[{"op":"delete","path":["L",{"id":"x"}]}]`, `{"L":[{"id":"y"}]}`, ""},
		{"order", `{"L":[{"id":"x"},{"id":"y"}]}`, `[{"op":"order","path":["L"],"value":["y","x"]}]`, `{"L":[{"id":"y"},{"id":"x"}]}`, ""},
		{"append by id", `{"L":[]}`, `[{"op":"set","path":["L",{"id":"n"}],"value":{"id":"n"}}]`, `{"L":[{"id":"n"}]}`, ""},
		{"base matches", `{"a":1}`, `[{"op":"set","path":["a"],"value":2,"base":1}]`, `{"a":2}`, ""},
		{"base differs", `{"a":5}`, `[{"op":"set","path":["a"],"value":2,"base":1}]`, ``, axerr.Conflict},
		{"missing id", `{"L":[]}`, `[{"op":"set","path":["L",{"id":"q"},"v"],"value":1}]`, ``, axerr.NotFound},
		{"order mismatch", `{"L":[{"id":"x"}]}`, `[{"op":"order","path":["L"],"value":["x","y"]}]`, ``, axerr.Conflict},
	}
	for _, c := range cases {
		t.Run(c.name, func(t *testing.T) {
			got := cfg(t, c.config)
			err := ApplyOps(got, parseOps(t, c.ops))
			if c.kind != "" {
				if axerr.KindOf(err) != c.kind {
					t.Fatalf("err %v, want %s", err, c.kind)
				}
				return
			}
			if err != nil {
				t.Fatal(err)
			}
			if s := string(jsonx.MarshalCompact(got)); s != c.want {
				t.Errorf("got %s want %s", s, c.want)
			}
		})
	}
}

func TestPathRefusesPositions(t *testing.T) {
	t.Parallel()
	var p Path
	if err := json.Unmarshal([]byte(`["Bars", 0]`), &p); err == nil {
		t.Error("a numeric index was accepted")
	}
	if err := json.Unmarshal([]byte(`["Bars", {"id": ""}]`), &p); err == nil {
		t.Error("an empty id was accepted")
	}
}
