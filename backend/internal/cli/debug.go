package cli

import (
	"context"
	"flag"
	"fmt"
	"io"
	"time"

	"github.com/axiom-shell/axiom/backend/internal/wayland/wire"
)

func debugCommand() *Command {
	return &Command{
		Name:    "debug",
		Summary: "Look into the environment axiom runs in",
		Subs: []*Command{{
			Name:    "wayland-globals",
			Summary: "List the Wayland protocols the compositor offers",
			Setup: func(fs *flag.FlagSet) Runner {
				return func(ctx context.Context, e *Env, args []string) error {
					socket, err := wire.SocketPath(e.Getenv)
					if err != nil {
						return err
					}
					globals, err := wire.Globals(socket, 5*time.Second)
					if err != nil {
						return err
					}
					return e.Output(globals, func(w io.Writer) {
						for _, g := range globals {
							fmt.Fprintf(w, "%-52s v%d\n", g.Interface, g.Version)
						}
					})
				}
			},
		}},
	}
}
