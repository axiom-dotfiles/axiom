package legacy

import (
	"crypto/sha256"
	"encoding/hex"
	"errors"
	"io/fs"
	"os"
	"path/filepath"
	"testing"

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
