package cli

import (
	"bytes"
	"context"
	"flag"
	"fmt"
	"io"
	"os"
	"path/filepath"

	"github.com/axiom-shell/axiom/backend/internal/axerr"
	"github.com/axiom-shell/axiom/backend/internal/buildinfo"
	"github.com/axiom-shell/axiom/backend/internal/fsx"
	"github.com/axiom-shell/axiom/backend/internal/tree"
)

func schemaCommand() *Command {
	return &Command{
		Name:    "schema",
		Summary: "Build and check the config schema from its YAML source (config/schema/)",
		Subs: []*Command{
			{
				Name:    "build",
				Summary: "Write config/json/config.schema.json from config/schema/",
				Setup: func(fs *flag.FlagSet) Runner {
					dir := fs.String("tree", "", "the axiom tree (default: the one here, or $AXIOM_TREE)")
					out := fs.String("o", "", "write here instead (- for stdout)")
					return func(ctx context.Context, e *Env, args []string) error {
						if len(args) > 0 {
							return usageError([]string{"axiom", "schema", "build"}, "takes no arguments")
						}
						root, data, err := buildSchema(e, *dir)
						if err != nil {
							return err
						}
						target := *out
						if target == "-" {
							_, err := e.Stdout.Write(data)
							return err
						}
						if target == "" {
							target = filepath.Join(root, tree.SchemaJSON)
						}
						if old, err := os.ReadFile(target); err == nil && bytes.Equal(old, data) {
							return e.Output(map[string]any{"path": target, "changed": false}, func(w io.Writer) {
								fmt.Fprintf(w, "%s is up to date\n", target)
							})
						}
						if err := fsx.WriteFile(target, data, 0o644); err != nil {
							return err
						}
						return e.Output(map[string]any{"path": target, "changed": true}, func(w io.Writer) {
							fmt.Fprintf(w, "wrote %s\n", target)
						})
					}
				},
			},
			{
				Name:    "check",
				Summary: "Check that config/schema/ builds, and that a built config/json/config.schema.json is fresh",
				Setup: func(fs *flag.FlagSet) Runner {
					dir := fs.String("tree", "", "the axiom tree (default: the one here, or $AXIOM_TREE)")
					return func(ctx context.Context, e *Env, args []string) error {
						root, data, err := buildSchema(e, *dir)
						if err != nil {
							return err
						}
						target := filepath.Join(root, tree.SchemaJSON)
						if old, err := os.ReadFile(target); err == nil && !bytes.Equal(old, data) {
							return axerr.New(axerr.InvalidConfig, "%s is stale (run `axiom schema build`)", tree.SchemaJSON)
						}
						return e.Output(map[string]any{"ok": true}, func(w io.Writer) {
							fmt.Fprintln(w, "schema ok")
						})
					}
				},
			},
			{
				Name:    "hash",
				Summary: "Print the schema's hash (what daemon.hello compares)",
				Setup: func(fs *flag.FlagSet) Runner {
					dir := fs.String("tree", "", "the axiom tree (default: the one here, or $AXIOM_TREE)")
					return func(ctx context.Context, e *Env, args []string) error {
						_, data, err := buildSchema(e, *dir)
						if err != nil {
							return err
						}
						hash := buildinfo.SchemaHash(data)
						return e.Output(map[string]any{"hash": hash}, func(w io.Writer) { fmt.Fprintln(w, hash) })
					}
				},
			},
		},
	}
}

func buildSchema(e *Env, dir string) (string, []byte, error) {
	wd, _ := os.Getwd()
	root, err := tree.Find(dir, e.Getenv, wd)
	if err != nil {
		return "", nil, err
	}
	data, err := tree.BuildSchema(root)
	return root, data, err
}
