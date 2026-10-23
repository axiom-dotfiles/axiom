package jsonx

import (
	"bytes"
	"io/fs"
	"math"
	"os"
	"path/filepath"
	"runtime"
	"strings"
	"testing"
)

func TestFormatNumber(t *testing.T) {
	t.Parallel()
	// Expected strings are what V4 prints (scratch probe, Qt 6.12)
	cases := map[float64]string{
		0: "0", math.Copysign(0, -1): "0", 1: "1", -1: "-1", 100: "100",
		0.30000000000000004: "0.30000000000000004", 1e21: "1e+21", 1e20: "100000000000000000000",
		1e-7: "1e-7", 0.000001: "0.000001", -1e-7: "-1e-7", 5e-324: "5e-324",
		123456789012345680000: "123456789012345680000", 1234.5e10: "12345000000000",
		1.5: "1.5", 1e300 * 10: "1e+301", 2.5e-5: "0.000025", 1.7976931348623157e308: "1.7976931348623157e+308",
	}
	for f, want := range cases {
		if got := FormatNumber(f); got != want {
			t.Errorf("FormatNumber(%v) = %q, want %q", f, got, want)
		}
	}
}

func TestKeyOrderMatchesJS(t *testing.T) {
	t.Parallel()
	// V4: {"1":4,"2":2,"4294967294":8,"b":1,"a":3,"-1":5,"01":6,"4294967295":7}
	o, err := Unmarshal([]byte(`{"b":1,"2":2,"a":3,"1":4,"-1":5,"01":6,"4294967295":7,"4294967294":8}`))
	if err != nil {
		t.Fatal(err)
	}
	got := string(MarshalCompact(o))
	want := `{"1":4,"2":2,"4294967294":8,"b":1,"a":3,"-1":5,"01":6,"4294967295":7}`
	if got != want {
		t.Errorf("got %s\nwant %s", got, want)
	}
}

func TestDuplicateKeysKeepFirstPlaceLastValue(t *testing.T) {
	t.Parallel()
	o, _ := Unmarshal([]byte(`{"a":1,"b":2,"a":3}`))
	if got := string(MarshalCompact(o)); got != `{"a":3,"b":2}` {
		t.Errorf("got %s", got)
	}
}

func TestStringEscapes(t *testing.T) {
	t.Parallel()
	// V4 escapes only ", \ and controls; U+2028/2029 and DEL stay raw
	in := "<>&  \u007f\u0000\u001f é\"\\\b\f\n\r\t"
	got := string(MarshalCompact(in))
	want := "\"<>&  \u007f\\u0000\\u001f é\\\"\\\\\\b\\f\\n\\r\\t\""
	if got != want {
		t.Errorf("got %q\nwant %q", got, want)
	}
	// Surrogate escapes: a pair is one character, a lone half is U+FFFD
	v, err := Unmarshal([]byte(`["😀","a\ud800b","\udc00"]`))
	if err != nil {
		t.Fatal(err)
	}
	if got := string(MarshalCompact(v)); got != "[\"😀\",\"a�b\",\"�\"]" {
		t.Errorf("surrogates: %s", got)
	}
}

func TestIndentedFormat(t *testing.T) {
	t.Parallel()
	v := Obj("a", Arr(1.0, Obj(), Arr()), "b", Obj("c", nil))
	want := "{\n  \"a\": [\n    1,\n    {},\n    []\n  ],\n  \"b\": {\n    \"c\": null\n  }\n}\n"
	if got := string(Marshal(v)); got != want {
		t.Errorf("got %q", got)
	}
}

func TestRejects(t *testing.T) {
	t.Parallel()
	for _, in := range []string{``, `{`, `[1,]`, `{"a":1,}`, `01`, `1.`, `.5`, `+1`, `"a`, "\"\x01\"", `nul`, `{"a" 1}`, `[1] 2`, `"\x"`, `NaN`} {
		if _, err := Unmarshal([]byte(in)); err == nil {
			t.Errorf("Unmarshal(%q) accepted", in)
		}
	}
	deep := strings.Repeat("[", 300) + strings.Repeat("]", 300)
	if _, err := Unmarshal([]byte(deep)); err == nil {
		t.Error("accepted 300 levels")
	}
}

func TestDelete(t *testing.T) {
	t.Parallel()
	o := Obj("a", 1.0, "1", 2.0, "b", 3.0)
	o.Delete("a")
	o.Delete("1")
	o.Set("a", 4.0)
	if got := string(MarshalCompact(o)); got != `{"b":3,"a":4}` {
		t.Errorf("got %s", got)
	}
}

// Every expected output of the shared fixtures is V4's own bytes: decoding
// and re-encoding each must give them back exactly.
func TestSharedExpectedFilesRoundTrip(t *testing.T) {
	t.Parallel()
	_, file, _, _ := runtime.Caller(0)
	dir := filepath.Join(filepath.Dir(file), "..", "..", "..", "tests", "fixtures", "shared")
	n := 0
	err := filepath.WalkDir(dir, func(path string, d fs.DirEntry, err error) error {
		if err != nil || !strings.HasSuffix(path, ".expected.json") {
			return err
		}
		data, err := os.ReadFile(path)
		if err != nil {
			return err
		}
		v, err := Unmarshal(data)
		if err != nil {
			t.Errorf("%s: %v", path, err)
			return nil
		}
		if got := Marshal(v); !bytes.Equal(got, data) {
			t.Errorf("%s: re-encoding differs", path)
		}
		n++
		return nil
	})
	if err != nil {
		t.Fatal(err)
	}
	if n < 100 {
		t.Fatalf("only %d expected files found", n)
	}
}

func FuzzRoundTrip(f *testing.F) {
	for _, seed := range []string{`{"a":[1,2,{"b":null}],"1":true}`, `"xé\n"`, `[1e21,-0,0.1]`, `{}`} {
		f.Add([]byte(seed))
	}
	f.Fuzz(func(t *testing.T, data []byte) {
		v, err := Unmarshal(data)
		if err != nil {
			return
		}
		out := Marshal(v)
		v2, err := Unmarshal(out)
		if err != nil {
			t.Fatalf("re-parse of %q: %v", out, err)
		}
		if !Equal(v, v2) && !hasNaN(v) {
			t.Fatalf("round trip changed %q", data)
		}
		if out2 := Marshal(v2); !bytes.Equal(out, out2) {
			t.Fatalf("encoding not stable for %q", data)
		}
	})
}

func hasNaN(v any) bool {
	switch t := v.(type) {
	case float64:
		return math.IsNaN(t) || math.IsInf(t, 0)
	case *Object:
		for _, k := range t.Keys() {
			if hasNaN(t.Value(k)) {
				return true
			}
		}
	case *Array:
		for _, x := range t.Items {
			if hasNaN(x) {
				return true
			}
		}
	}
	return false
}
