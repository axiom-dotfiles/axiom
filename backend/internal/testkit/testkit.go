// Package testkit loads the shared fixtures (tests/fixtures/shared/): the
// cases the shell's JS helpers and this binary must agree on byte for byte.
// tests/Shared.qml is the JS side of the same format; see
// docs/dev/backend/README.md › Shared fixtures.
package testkit

import (
	"bytes"
	"fmt"
	"os"
	"path/filepath"
	"runtime"
	"strings"
	"sync"
	"testing"

	"github.com/axiom-shell/axiom/backend/internal/jsonx"
)

// Case is one shared case: an op, its arguments (references resolved) and
// the exact bytes its output must encode to.
type Case struct {
	Name     string
	Op       string
	Args     []any
	Expected []byte
}

// RepoRoot is the axiom checkout this package was built from.
func RepoRoot() string {
	_, file, _, _ := runtime.Caller(0)
	// backend/internal/testkit/testkit.go → the repo root
	return filepath.Clean(filepath.Join(filepath.Dir(file), "..", "..", ".."))
}

// SharedDir is tests/fixtures/shared.
func SharedDir() string { return filepath.Join(RepoRoot(), "tests", "fixtures", "shared") }

var (
	indexOnce sync.Once
	index     []string
	indexErr  error
)

// Cases returns every case whose op starts with prefix (e.g. "schema."),
// failing t when the fixtures can't be read.
func Cases(t testing.TB, prefix string) []Case {
	t.Helper()
	indexOnce.Do(func() {
		var raw any
		raw, indexErr = readJSON(filepath.Join(SharedDir(), "index.json"))
		if indexErr != nil {
			return
		}
		obj, _ := jsonx.AsObject(raw)
		arr, ok := jsonx.AsArray(obj.Value("cases"))
		if !ok {
			indexErr = fmt.Errorf("index.json has no cases")
			return
		}
		for _, v := range arr.Items {
			index = append(index, v.(string))
		}
	})
	if indexErr != nil {
		t.Fatalf("shared fixtures (generated: scripts/generate.sh --fixtures): %v", indexErr)
	}
	var cases []Case
	for _, name := range index {
		c, err := load(name)
		if err != nil {
			t.Fatalf("shared fixture %s: %v", name, err)
		}
		if strings.HasPrefix(c.Op, prefix) {
			cases = append(cases, c)
		}
	}
	if len(cases) == 0 {
		t.Fatalf("no shared cases for %q", prefix)
	}
	return cases
}

func load(name string) (Case, error) {
	dir := SharedDir()
	raw, err := readJSON(filepath.Join(dir, filepath.FromSlash(name)+".json"))
	if err != nil {
		return Case{}, err
	}
	spec, ok := jsonx.AsObject(raw)
	if !ok {
		return Case{}, fmt.Errorf("not an object")
	}
	op, _ := spec.Value("op").(string)
	argsArr, ok := jsonx.AsArray(spec.Value("args"))
	if !ok {
		return Case{}, fmt.Errorf("no args")
	}
	expected, err := os.ReadFile(filepath.Join(dir, filepath.FromSlash(name)+".expected.json"))
	if err != nil {
		return Case{}, err
	}
	args := make([]any, len(argsArr.Items))
	for i, a := range argsArr.Items {
		if args[i], err = resolve(a); err != nil {
			return Case{}, err
		}
	}
	return Case{Name: name, Op: op, Args: args, Expected: expected}, nil
}

var (
	schemaMu    sync.Mutex
	schemaCache = map[string]any{}
)

// Schema returns a frozen schema from schemas/<name>.schema.json. The same
// object is returned on every call, so sub-schemas keep their identity.
func Schema(name string) (any, error) {
	schemaMu.Lock()
	defer schemaMu.Unlock()
	if s, ok := schemaCache[name]; ok {
		return s, nil
	}
	s, err := readJSON(filepath.Join(SharedDir(), "schemas", name+".schema.json"))
	if err != nil {
		return nil, err
	}
	schemaCache[name] = s
	return s, nil
}

// resolve replaces {"$blob": h} with the blob and {"$fixtureSchema": n,
// "pointer": p} with that (shared) schema object.
func resolve(v any) (any, error) {
	switch t := v.(type) {
	case *jsonx.Object:
		if t.Len() == 1 && t.Has("$blob") {
			h, _ := t.Value("$blob").(string)
			blob, err := readJSON(filepath.Join(SharedDir(), "blobs", h+".json"))
			if err != nil {
				return nil, err
			}
			return resolve(blob)
		}
		if name, ok := t.Value("$fixtureSchema").(string); ok && (t.Len() == 1 || (t.Len() == 2 && t.Has("pointer"))) {
			node, err := Schema(name)
			if err != nil {
				return nil, err
			}
			pointer, _ := t.Value("pointer").(string)
			for _, part := range strings.Split(pointer, "/")[1:] {
				part = strings.ReplaceAll(strings.ReplaceAll(part, "~1", "/"), "~0", "~")
				switch n := node.(type) {
				case *jsonx.Object:
					node = n.Value(part)
				case *jsonx.Array:
					var i int
					fmt.Sscan(part, &i)
					node = n.Items[i]
				}
			}
			return node, nil
		}
		for _, k := range t.Keys() {
			r, err := resolve(t.Value(k))
			if err != nil {
				return nil, err
			}
			t.Set(k, r)
		}
		return t, nil
	case *jsonx.Array:
		for i, x := range t.Items {
			r, err := resolve(x)
			if err != nil {
				return nil, err
			}
			t.Items[i] = r
		}
		return t, nil
	}
	return v, nil
}

func readJSON(path string) (any, error) {
	data, err := os.ReadFile(path)
	if err != nil {
		return nil, err
	}
	return jsonx.Unmarshal(data)
}

// Compare fails t when got doesn't encode to c's expected bytes, showing
// the first differing line.
func (c Case) Compare(t testing.TB, got any) {
	t.Helper()
	actual := jsonx.Marshal(got)
	if bytes.Equal(actual, c.Expected) {
		return
	}
	a := strings.Split(string(actual), "\n")
	e := strings.Split(string(c.Expected), "\n")
	for i := 0; i < len(a) || i < len(e); i++ {
		var x, y string
		if i < len(a) {
			x = a[i]
		}
		if i < len(e) {
			y = e[i]
		}
		if x != y {
			t.Errorf("%s: line %d: got %q, want %q", c.Name, i+1, x, y)
			return
		}
	}
}
