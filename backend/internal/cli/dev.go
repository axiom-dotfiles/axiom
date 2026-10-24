package cli

import (
	"context"
	"flag"
	"fmt"
	"io"

	"github.com/axiom-shell/axiom/backend/internal/daemon"
)

func devCommand() *Command {
	show := func(ctx context.Context, e *Env, method string, params any) error {
		var st daemon.DevState
		if err := call(ctx, e, method, params, &st); err != nil {
			return err
		}
		return e.Output(st, func(w io.Writer) {
			state := "off"
			if st.Enabled {
				state = "on"
			}
			fmt.Fprintf(w, "dev mode %s\nbinary    %s\ninstalled %s\n", state, st.Binary, st.Installed)
			if !st.Available {
				fmt.Fprintf(w, "builds    %s\n", st.Unavailable)
			} else if st.Building {
				fmt.Fprintln(w, "builds    building…")
			}
			if b := st.LastBuild; b != nil {
				result := "ok"
				if !b.OK {
					result = "failed"
				}
				fmt.Fprintf(w, "last build %s at %s\n", result, b.At.Format("15:04:05"))
				if !b.OK {
					fmt.Fprintln(w, b.Output)
				}
			}
		})
	}
	leaf := func(name, summary string, run func(ctx context.Context, e *Env) error) *Command {
		return &Command{
			Name:    name,
			Summary: summary,
			Setup: func(fs *flag.FlagSet) Runner {
				return func(ctx context.Context, e *Env, args []string) error {
					if len(args) > 0 {
						return usageError([]string{"axiom", "dev", name}, "takes no arguments")
					}
					return run(ctx, e)
				}
			},
		}
	}
	setDev := func(on bool) func(ctx context.Context, e *Env) error {
		return func(ctx context.Context, e *Env) error {
			return show(ctx, e, "dev.set", map[string]bool{"enabled": on})
		}
	}
	return &Command{
		Name:    "dev",
		Summary: "Dev mode: the schema and the Go source rebuilt as you edit them",
		Help: `Dev mode is switched while axiom runs, and remembered across sessions.
While it's on, a YAML edit rebuilds the schema, a tree whose schema
isn't the binary's may still save its config, the log is at debug level,
and an edit to the Go source builds a binary into
$XDG_STATE_HOME/axiom/dev/ and re-execs into it, the shell running on.
Turning it off goes back to the installed binary.`,
		Subs: []*Command{
			leaf("status", "Show whether dev mode is on, and the last build", func(ctx context.Context, e *Env) error {
				return show(ctx, e, "dev.get", nil)
			}),
			leaf("on", "Turn dev mode on (and keep it on across sessions)", setDev(true)),
			leaf("off", "Turn dev mode off, back on the installed binary", setDev(false)),
			leaf("rebuild", "Build the Go source now and re-exec into it", func(ctx context.Context, e *Env) error {
				return call(ctx, e, "dev.rebuild", nil, nil)
			}),
		},
	}
}
