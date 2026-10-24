package testkit

import (
	"bufio"
	"compress/gzip"
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"os"
	"path/filepath"
	"testing"

	"github.com/axiom-shell/axiom/backend/internal/jsonx"
)

// FrozenCase is one case of the format-1 migration, recorded from the
// shell's ConfigMigration.qml (and the corpus of old configs) before it
// was removed: an input and the sha256 of the bytes V4 made of it.
type FrozenCase struct {
	Name   string
	Op     string // migrate (legacy.Migrate) or load (config.LoadLegacy)
	Input  any
	SHA256 string
}

// FrozenFile holds them, one JSON object per line, gzipped.
func FrozenFile() string {
	return filepath.Join(RepoRoot(), "backend", "internal", "migrate", "legacy", "testdata", "frozen.jsonl.gz")
}

// Frozen returns the frozen cases of op.
func Frozen(t testing.TB, op string) []FrozenCase {
	t.Helper()
	f, err := os.Open(FrozenFile())
	if err != nil {
		t.Fatal(err)
	}
	defer f.Close()
	gz, err := gzip.NewReader(f)
	if err != nil {
		t.Fatal(err)
	}
	var cases []FrozenCase
	lines := bufio.NewScanner(gz)
	lines.Buffer(nil, 64<<20)
	for lines.Scan() {
		var head struct {
			Name   string          `json:"name"`
			Op     string          `json:"op"`
			Input  json.RawMessage `json:"input"`
			SHA256 string          `json:"sha256"`
		}
		if err := json.Unmarshal(lines.Bytes(), &head); err != nil {
			t.Fatal(err)
		}
		if head.Op != op {
			continue
		}
		input, err := jsonx.Unmarshal(head.Input)
		if err != nil {
			t.Fatalf("%s: %v", head.Name, err)
		}
		cases = append(cases, FrozenCase{Name: head.Name, Op: head.Op, Input: input, SHA256: head.SHA256})
	}
	if err := lines.Err(); err != nil {
		t.Fatal(err)
	}
	if len(cases) == 0 {
		t.Fatalf("no frozen cases for %q", op)
	}
	return cases
}

// Check fails t when got doesn't encode to the frozen bytes.
func (c FrozenCase) Check(t testing.TB, got any) {
	t.Helper()
	data := jsonx.Marshal(got)
	if sum := sha256.Sum256(data); hex.EncodeToString(sum[:]) != c.SHA256 {
		if len(data) > 4096 {
			data = data[:4096]
		}
		t.Errorf("%s: the output isn't the frozen one; got (start):\n%s", c.Name, data)
	}
}
