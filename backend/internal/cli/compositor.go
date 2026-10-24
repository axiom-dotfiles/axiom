package cli

import (
	"context"
	"flag"
	"fmt"
	"io"

	"github.com/axiom-shell/axiom/backend/internal/compositor/takeover"
)

func compositorCommand() *Command {
	return &Command{
		Name:    "compositor",
		Summary: "The compositor's config: taking it over for the managed mode and giving it back",
		Subs: []*Command{
			takeoverCommand("check", "Say what taking the config over would do", takeover.Check),
			takeoverCommand("claim", "Take the config over for the managed mode", takeover.Claim),
			takeoverCommand("release", "Give the config back on leaving the managed mode", takeover.Release),
		},
	}
}

func takeoverCommand(verb, summary string, run func(context.Context, takeover.Options) (string, error)) *Command {
	trail := []string{"axiom", "compositor", verb}
	return &Command{
		Name:    verb,
		Summary: summary,
		Args:    "DIR HEADER [FALLBACK]",
		Help: "DIR is the compositor's config dir, HEADER the first-line prefix of a file axiom wrote, " +
			"FALLBACK what release writes when nothing was set aside (release needs it). " +
			"Prints one word (docs/dev/hyprland/managed-takeover.md); never touches a symlinked or git-tracked dir.",
		Setup: func(fs *flag.FlagSet) Runner {
			kind := fs.String("kind", "", "hyprland, sway or niri")
			return func(ctx context.Context, e *Env, args []string) error {
				k, ok := takeover.KindNamed(*kind)
				if !ok {
					return usageError(trail, fmt.Sprintf("unknown --kind %q", *kind))
				}
				if len(args) < 2 || len(args) > 3 || (verb == "release" && len(args) < 3) {
					return usageError(trail, "takes DIR HEADER [FALLBACK] (release needs FALLBACK)")
				}
				o := takeover.Options{Kind: k, Dir: args[0], Header: args[1], Getenv: e.Getenv}
				if len(args) == 3 {
					o.Fallback = args[2]
				}
				result, err := run(ctx, o)
				if err != nil {
					return err
				}
				return e.Output(map[string]any{"result": result}, func(w io.Writer) { fmt.Fprintln(w, result) })
			}
		},
	}
}
