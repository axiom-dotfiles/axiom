// Package tree finds the axiom tree (the shell's QML and the config
// schema's source) a command works on, and builds the JSON schema from it:
// config/schema/**.yaml → config/json/config.schema.json.
package tree

import (
	"errors"
	"fmt"
	"io/fs"
	"os"
	"path/filepath"

	"github.com/axiom-shell/axiom/backend/internal/axerr"
	"github.com/axiom-shell/axiom/backend/internal/jsonx"
	"github.com/axiom-shell/axiom/backend/internal/schema/yamlsrc"
)

// Paths inside a tree
const (
	SchemaSource = "config/schema"
	SchemaJSON   = "config/json/config.schema.json"
	shellQML     = "shell.qml"
)

// Find is the tree to use: dir when given, else $AXIOM_TREE, else the
// nearest directory up from start holding shell.qml and config/.
func Find(dir string, getenv func(string) string, start string) (string, error) {
	if dir == "" {
		dir = getenv("AXIOM_TREE")
	}
	if dir != "" {
		abs, err := filepath.Abs(dir)
		if err != nil {
			return "", err
		}
		if !isTree(abs) {
			return "", axerr.New(axerr.NotFound, "%s isn't an axiom tree (no shell.qml and config/)", abs)
		}
		return abs, nil
	}
	for d := start; ; d = filepath.Dir(d) {
		if isTree(d) {
			return d, nil
		}
		if filepath.Dir(d) == d {
			return "", axerr.New(axerr.NotFound, "no axiom tree here or above (pass --tree)")
		}
	}
}

func isTree(dir string) bool {
	if _, err := os.Stat(filepath.Join(dir, shellQML)); err != nil {
		return false
	}
	info, err := os.Stat(filepath.Join(dir, "config"))
	return err == nil && info.IsDir()
}

// BuildSchema assembles the tree's YAML schema source into the JSON
// schema's bytes.
func BuildSchema(dir string) ([]byte, error) {
	src := filepath.Join(dir, SchemaSource)
	if _, err := os.Stat(filepath.Join(src, yamlsrc.IndexFile)); errors.Is(err, fs.ErrNotExist) {
		return nil, axerr.New(axerr.NotFound, "%s has no schema source (%s/%s)", dir, SchemaSource, yamlsrc.IndexFile)
	}
	root, err := yamlsrc.Assemble(os.DirFS(src))
	if err != nil {
		var errs yamlsrc.Errors
		if errors.As(err, &errs) {
			e := &axerr.Error{Kind: axerr.InvalidConfig, Message: fmt.Sprintf("the schema source has %d problems", len(errs))}
			for _, x := range errs {
				where := filepath.Join(SchemaSource, x.File)
				if x.Line > 0 {
					where = fmt.Sprintf("%s:%d:%d", where, x.Line, x.Column)
				}
				e.Issues = append(e.Issues, axerr.Issue{Path: where, Message: x.Msg})
			}
			return nil, e
		}
		return nil, axerr.Wrap(axerr.InvalidConfig, err, "the schema source")
	}
	return jsonx.Marshal(root), nil
}
