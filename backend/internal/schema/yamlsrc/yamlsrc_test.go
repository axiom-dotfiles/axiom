package yamlsrc

import (
	"bytes"
	"os"
	"path/filepath"
	"strings"
	"testing"
	"testing/fstest"

	"github.com/axiom-shell/axiom/backend/internal/jsonx"
	"github.com/axiom-shell/axiom/backend/internal/testkit"
)

// The frozen legacy schema split into YAML and joined again gives the same
// schema exactly, so the YAML source can stand for the JSON.
func TestSplitAssembleRoundTrip(t *testing.T) {
	t.Parallel()
	data, err := os.ReadFile(filepath.Join(testkit.SharedDir(), "schemas", "legacy-v75.schema.json"))
	if err != nil {
		t.Fatal(err)
	}
	root, err := jsonx.Unmarshal(data)
	if err != nil {
		t.Fatal(err)
	}
	files, err := Split(root.(*jsonx.Object), nil)
	if err != nil {
		t.Fatal(err)
	}
	fsys := fstest.MapFS{}
	for name, content := range files {
		fsys[name] = &fstest.MapFile{Data: content}
	}
	got, err := Assemble(fsys)
	if err != nil {
		t.Fatal(err)
	}
	if !bytes.Equal(jsonx.Marshal(got), jsonx.Marshal(root)) {
		t.Fatal("assembled schema differs from the original")
	}
}

func TestStrictRefusals(t *testing.T) {
	t.Parallel()
	cases := map[string]string{
		"a: &x 1\nb: *x\n":      "anchors",
		"a: {<<: {b: 1}}\n":     "merge keys",
		"a: !custom 1\n":        "values aren't allowed",
		"a: !!binary aGk=\n":    "values aren't allowed",
		"a: 2001-12-14\n":       "timestamp",
		"a: on\n":               "YAML 1.1",
		"a: yes\n":              "YAML 1.1",
		"off: 1\n":              "quote the key",
		"a:\n":                  "missing value",
		"a: ~\n":                "missing value",
		"a: True\n":             "true or false",
		"a: 0x1F\n":             "decimal",
		"a: 1_000\n":            "decimal",
		"a: .inf\n":             "decimal",
		"a: .nan\n":             "decimal",
		"a: 9007199254740993\n": "too large",
		"a: 1\na: 2\n":          "duplicate",
		"1: a\n":                "must be a string",
		"a: 1\n---\nb: 2\n":     "more than one",
		"":                      "empty",
	}
	for in, want := range cases {
		_, err := Parse("t.yaml", []byte(in))
		if err == nil || !strings.Contains(err.Error(), want) {
			t.Errorf("Parse(%q) = %v, want an error about %q", in, err, want)
		}
	}
}

func TestStrictAccepts(t *testing.T) {
	t.Parallel()
	in := "a: \"on\"\nb: [1, 2.5, -0.000001, 1e+21]\nc: null\nd: true\ne: |\n  two\n  lines\n\"off\": x\n"
	v, err := Parse("t.yaml", []byte(in))
	if err != nil {
		t.Fatal(err)
	}
	want := `{"a":"on","b":[1,2.5,-0.000001,1e+21],"c":null,"d":true,"e":"two\nlines\n","off":"x"}`
	if got := string(jsonx.MarshalCompact(v)); got != want {
		t.Errorf("got %s", got)
	}
}

func TestCheckRefusesTyposAndBadRefs(t *testing.T) {
	t.Parallel()
	fsys := fstest.MapFS{
		IndexFile:                   {Data: []byte("type: object\nproperties: {}\nsections: [A]\ndefinitions: [D]\n")},
		AnnotationsFile:             {Data: []byte("x-known: \"\"\n")},
		"sections/A.yaml":           {Data: []byte("type: object\ndefualt: {}\nx-unknwon: 1\nx-known: 1\nproperties:\n  b: {$ref: \"#/definitions/Nope\"}\n  c: {type: strin}\n  d: {type: string, pattern: \"(?<=a)b\"}\n")},
		"definitions/common/D.yaml": {Data: []byte("type: object\n")},
		"definitions/common/E.yaml": {Data: []byte("type: object\n")},
	}
	_, err := Assemble(fsys)
	if err == nil {
		t.Fatal("accepted")
	}
	for _, want := range []string{`unknown keyword "defualt"`, "unknown annotation x-unknwon", `names no definition`, "type strin", "doesn't compile", "E.yaml: not listed", "sections/A.yaml:2:1"} {
		if !strings.Contains(err.Error(), want) {
			t.Errorf("missing %q in:\n%v", want, err)
		}
	}
}
