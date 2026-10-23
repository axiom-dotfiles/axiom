package cli

import (
	"context"
	"flag"
	"fmt"
	"io"
	"strings"

	"github.com/axiom-shell/axiom/backend/internal/ipcroute"
)

func ipcCommand() *Command {
	return &Command{
		Name:    "ipc",
		Summary: "Call a function of the shell: axiom ipc <target> <function> [args]",
		Args:    "TARGET FUNCTION [ARGS…] | list",
		Help: `Every IPC target of the shell, as docs/dev/generated/ipc.md lists them
(axiom ipc list shows those the running shell has registered). The named
commands (axiom launcher toggle, …) are shorter ways to the common ones.`,
		Setup: func(fs *flag.FlagSet) Runner {
			return func(ctx context.Context, e *Env, args []string) error {
				if len(args) == 1 && args[0] == "list" {
					var targets []ipcroute.Target
					if err := call(ctx, e, "ipc.list", nil, &targets); err != nil {
						return err
					}
					return e.Output(targets, func(w io.Writer) {
						for _, t := range targets {
							var fns []string
							for _, f := range t.Functions {
								fns = append(fns, f.Name)
							}
							fmt.Fprintf(w, "%-18s %s\n", t.Name, strings.Join(fns, " "))
						}
					})
				}
				if len(args) < 2 {
					return usageError([]string{"axiom", "ipc"}, "takes a target and a function")
				}
				return ipcCall(ctx, e, args[0], args[1], args[2:])
			}
		},
	}
}

func ipcCall(ctx context.Context, e *Env, target, function string, args []string) error {
	var result string
	if err := call(ctx, e, "ipc.call", ipcroute.CallParams{Target: target, Function: function, Args: args}, &result); err != nil {
		return err
	}
	return e.Output(map[string]string{"result": result}, func(w io.Writer) {
		if result != "" {
			fmt.Fprintln(w, result)
		}
	})
}

func lockCommand() *Command {
	return &Command{
		Name:    "lock",
		Summary: "Lock the session (exits 0 only once the lock screen is up)",
		Setup: func(fs *flag.FlagSet) Runner {
			return func(ctx context.Context, e *Env, args []string) error {
				return call(ctx, e, "lock.lock", nil, nil)
			}
		},
	}
}
