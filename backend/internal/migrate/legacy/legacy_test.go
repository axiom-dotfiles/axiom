package legacy

import (
	"crypto/sha256"
	"encoding/hex"
	"errors"
	"io/fs"
	"os"
	"path/filepath"
	"testing"

	"github.com/axiom-shell/axiom/backend/internal/jsonx"
	"github.com/axiom-shell/axiom/backend/internal/testkit"
)

// Every legacy.migrate case recorded from the shell: the frozen code run
// here must give V4's bytes exactly.
func TestSharedMigrateCases(t *testing.T) {
	t.Parallel()
	for _, c := range testkit.Cases(t, "legacy.migrate") {
		t.Run(c.Name, func(t *testing.T) {
			t.Parallel()
			res, err := Migrate(c.Args[0])
			if err != nil {
				t.Fatal(err)
			}
			c.Compare(t, res.Object())
		})
	}
}

// ConfigMigration.qml is the record legacy.js was converted from: both are
// frozen, so the QML must still be the bytes it was then (until it's gone).
func TestConfigMigrationQMLIsFrozen(t *testing.T) {
	t.Parallel()
	data, err := os.ReadFile(filepath.Join(testkit.RepoRoot(), "components", "methods", "ConfigMigration.qml"))
	if errors.Is(err, fs.ErrNotExist) {
		t.Skip("removed")
	}
	if err != nil {
		t.Fatal(err)
	}
	const frozen = "4e3526aa440615d5d769126b5fe95bfd95d7e85a28e741fa02d9f23419a50d4c"
	if sum := sha256.Sum256(data); hex.EncodeToString(sum[:]) != frozen {
		t.Error("components/methods/ConfigMigration.qml changed: the format-1 migrations are frozen (docs/recipes/migration.md)")
	}
}

// The version-75 schema is the last format-1 one, as committed before the
// binary took over (main's eb39e97): frozen with the migrations.
func TestSchemaIsFrozen(t *testing.T) {
	t.Parallel()
	const frozen = "64f7fa83036167d915d7b231001a4cac598573d921ed59116e6f7712376d2b0d"
	if sum := sha256.Sum256(schemaV75); hex.EncodeToString(sum[:]) != frozen {
		t.Error("schema-v75.json changed: it's frozen with the format-1 migrations")
	}
	if Schema().Value("properties").(*jsonx.Object).Value("version").(*jsonx.Object).Value("default") != float64(LastVersion) {
		t.Error("schema-v75.json isn't version 75's")
	}
}
