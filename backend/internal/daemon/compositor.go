package daemon

import (
	"context"

	"github.com/axiom-shell/axiom/backend/internal/axerr"
	"github.com/axiom-shell/axiom/backend/internal/compositor/takeover"
	"github.com/axiom-shell/axiom/backend/internal/rpc"
)

// takeoverParams are one takeover verb on a compositor's config dir, as the
// shell's ConfigTakeover asks for it
type takeoverParams struct {
	Verb     string `json:"verb"` // check, claim or release
	Kind     string `json:"kind"`
	Dir      string `json:"dir"`
	Header   string `json:"header"`
	Fallback string `json:"fallback"`
}

// compositorPart: the compositor's config (internal/compositor). For now
// the managed mode's takeover, which the shell's config writers drive.
func (d *Daemon) compositorPart() part {
	return part{name: "compositor", methods: d.compositorMethods}
}

func (d *Daemon) compositorMethods(reg *rpc.Registry) {
	verbs := map[string]func(context.Context, takeover.Options) (string, error){
		"check": takeover.Check, "claim": takeover.Claim, "release": takeover.Release,
	}
	rpc.Handle(reg, "compositor.takeover", func(ctx context.Context, c *rpc.Conn, p takeoverParams) (map[string]string, error) {
		// It moves the user's compositor config: only the shell's
		// Compositor settings decide that
		if !fromShell(c) {
			return nil, axerr.New(axerr.Refused, "only the shell takes a compositor's config over")
		}
		run, ok := verbs[p.Verb]
		if !ok {
			return nil, axerr.New(axerr.BadRequest, "unknown takeover verb %q", p.Verb)
		}
		kind, ok := takeover.KindNamed(p.Kind)
		if !ok {
			return nil, axerr.New(axerr.BadRequest, "unknown compositor %q", p.Kind)
		}
		result, err := run(ctx, takeover.Options{Kind: kind, Dir: p.Dir, Header: p.Header, Fallback: p.Fallback, Getenv: d.opts.Getenv})
		if err != nil {
			return nil, err
		}
		return map[string]string{"result": result}, nil
	})
}
