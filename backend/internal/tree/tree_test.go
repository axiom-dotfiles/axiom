package tree

import (
	"os"
	"path/filepath"
	"testing"
)

func makeTree(t *testing.T, dir string) {
	t.Helper()
	if err := os.MkdirAll(filepath.Join(dir, "config"), 0o755); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(filepath.Join(dir, shellQML), nil, 0o644); err != nil {
		t.Fatal(err)
	}
}

// Found from the folder a command runs in first, then where quickshell
// finds `-c axiom`: an autostart's `axiom run` runs from $HOME.
func TestFind(t *testing.T) {
	t.Parallel()
	root := t.TempDir()
	clone := filepath.Join(root, "work", "axiom")
	user := filepath.Join(root, "config", "quickshell", "axiom")
	system := filepath.Join(root, "xdg", "quickshell", "axiom")
	for _, d := range []string{clone, user, system} {
		makeTree(t, d)
	}
	nowhere := filepath.Join(root, "home")
	os.MkdirAll(nowhere, 0o755)
	env := func(vars map[string]string) func(string) string {
		return func(k string) string { return vars[k] }
	}
	cases := []struct {
		name  string
		vars  map[string]string
		start string
		want  string
	}{
		{"inside a clone", map[string]string{"XDG_CONFIG_HOME": filepath.Join(root, "config")}, filepath.Join(clone, "config"), clone},
		{"the user's", map[string]string{"XDG_CONFIG_HOME": filepath.Join(root, "config")}, nowhere, user},
		{"the system's", map[string]string{"HOME": nowhere, "XDG_CONFIG_DIRS": filepath.Join(root, "xdg")}, nowhere, system},
		{"AXIOM_TREE first", map[string]string{"AXIOM_TREE": system, "XDG_CONFIG_HOME": filepath.Join(root, "config")}, clone, system},
		{"none", map[string]string{"HOME": nowhere, "XDG_CONFIG_DIRS": filepath.Join(root, "none")}, nowhere, ""},
	}
	for _, c := range cases {
		t.Run(c.name, func(t *testing.T) {
			t.Parallel()
			got, err := Find("", env(c.vars), c.start)
			if c.want == "" {
				if err == nil {
					t.Errorf("found %s", got)
				}
				return
			}
			if err != nil || got != c.want {
				t.Errorf("got %q %v, want %q", got, err, c.want)
			}
		})
	}
}
