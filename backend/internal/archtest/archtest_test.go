// Package archtest checks the dependency rules of backend/AGENTS.md on the
// source: the pure packages (the Go side of components/methods/) do no I/O,
// so they import nothing that reaches files, sockets or processes, and they
// import only each other among axiom's own packages.
package archtest

import (
	"go/parser"
	"go/token"
	"os"
	"path/filepath"
	"strconv"
	"strings"
	"testing"
)

const module = "github.com/axiom-shell/axiom/backend/"

// The pure packages, by directory under internal/ (a trailing / covers a
// whole subtree)
var pure = []string{"axerr", "jsonx", "schema", "config", "migrate/", "share"}

// What a pure package may never import
var forbidden = []string{"os", "os/exec", "os/signal", "net", "syscall", "golang.org/x/sys", "io/ioutil", "plugin", "unsafe"}

func isPure(rel string) bool {
	for _, p := range pure {
		if strings.HasSuffix(p, "/") {
			if rel == strings.TrimSuffix(p, "/") || strings.HasPrefix(rel, p) {
				return true
			}
		} else if rel == p || strings.HasPrefix(rel, p+"/") {
			return true
		}
	}
	return false
}

func TestPurePackagesDoNoIO(t *testing.T) {
	t.Parallel()
	internal, err := filepath.Abs("..")
	if err != nil {
		t.Fatal(err)
	}
	checked := 0
	err = filepath.WalkDir(internal, func(path string, d os.DirEntry, err error) error {
		if err != nil || d.IsDir() || !strings.HasSuffix(path, ".go") || strings.HasSuffix(path, "_test.go") {
			return err
		}
		rel, _ := filepath.Rel(internal, filepath.Dir(path))
		rel = filepath.ToSlash(rel)
		if !isPure(rel) {
			return nil
		}
		f, err := parser.ParseFile(token.NewFileSet(), path, nil, parser.ImportsOnly)
		if err != nil {
			return err
		}
		checked++
		for _, imp := range f.Imports {
			name, _ := strconv.Unquote(imp.Path.Value)
			for _, bad := range forbidden {
				if name == bad || strings.HasPrefix(name, bad+"/") {
					t.Errorf("%s (pure) imports %s", rel, name)
				}
			}
			if own, ok := strings.CutPrefix(name, module+"internal/"); ok && !isPure(own) {
				t.Errorf("%s (pure) imports %s, which isn't pure", rel, own)
			}
		}
		return nil
	})
	if err != nil {
		t.Fatal(err)
	}
	if checked == 0 {
		t.Fatal("no pure package files found")
	}
}
