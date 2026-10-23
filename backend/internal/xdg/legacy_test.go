package xdg

import (
	"os"
	"path/filepath"
	"strings"
	"testing"
	"time"
)

func write(t *testing.T, path, content string) {
	t.Helper()
	if err := os.MkdirAll(filepath.Dir(path), 0o755); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(path, []byte(content), 0o644); err != nil {
		t.Fatal(err)
	}
}

func TestMoveLegacy(t *testing.T) {
	t.Parallel()
	tree, home := t.TempDir(), t.TempDir()
	d := Resolve(func(k string) string {
		if k == "HOME" {
			return home
		}
		return ""
	})
	write(t, filepath.Join(tree, "config/user/config.json"), `{"version": 70}`)
	write(t, filepath.Join(tree, "config/user/saved/a.json"), `{}`)
	write(t, filepath.Join(tree, "config/state/look.json"), `{"x": 1}`)
	write(t, filepath.Join(tree, "config/state/notes/n.md"), "note")
	write(t, filepath.Join(tree, "config/themes/generated/g.json"), "{}")
	// Already in place: kept
	write(t, filepath.Join(d.UI, "look.json"), `{"x": 2}`)

	moved, err := MoveLegacy(tree, d, time.Unix(0, 0))
	if err != nil || !moved {
		t.Fatalf("moved %v err %v", moved, err)
	}
	for path, want := range map[string]string{
		d.Config + "config.json":     `{"version": 70}`,
		d.Config + "saved/a.json":    `{}`,
		d.UI + "look.json":           `{"x": 2}`,
		d.Notes + "n.md":             "note",
		d.GeneratedThemes + "g.json": "{}",
	} {
		got, err := os.ReadFile(path)
		if err != nil || string(got) != want {
			t.Errorf("%s: %q %v", path, got, err)
		}
	}
	if _, err := os.Stat(d.UI + "notes"); err == nil {
		t.Error("notes copied with the UI state too")
	}
	marker, _ := os.ReadFile(filepath.Join(tree, "config/user", MovedMarker))
	if !strings.Contains(string(marker), d.Config) {
		t.Errorf("marker: %s", marker)
	}
	if moved, _ := MoveLegacy(tree, d, time.Now()); moved {
		t.Error("moved twice")
	}
}
