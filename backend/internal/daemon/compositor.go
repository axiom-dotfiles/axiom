package daemon

import (
	"context"
	"encoding/json"

	"github.com/axiom-shell/axiom/backend/internal/axerr"
	"github.com/axiom-shell/axiom/backend/internal/compositor/binds"
	"github.com/axiom-shell/axiom/backend/internal/compositor/takeover"
	"github.com/axiom-shell/axiom/backend/internal/jsonx"
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

// bindsParams are one bind merge verb, as the shell's UserBindMerge asks
// for it
type bindsParams struct {
	Verb  string          `json:"verb"` // extract or remove
	Kind  string          `json:"kind"`
	Dir   string          `json:"dir"`
	Only  string          `json:"only"`
	Sites json.RawMessage `json:"sites"`
}

// compositorPart: the compositor's config (internal/compositor). For now
// the managed mode's takeover and the bind merge, which the shell's config
// writers drive.
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
	rpc.Handle(reg, "compositor.binds", func(ctx context.Context, c *rpc.Conn, p bindsParams) (json.RawMessage, error) {
		// remove edits the user's files: only the shell's Merge does that
		if !fromShell(c) {
			return nil, axerr.New(axerr.Refused, "only the shell moves the user's binds")
		}
		table, err := binds.LoadActions(d.opts.Tree)
		if err != nil {
			return nil, err
		}
		o := binds.Options{Kind: p.Kind, Dir: p.Dir, Only: p.Only, Actions: table, Getenv: d.opts.Getenv}
		var result *jsonx.Object
		switch p.Verb {
		case "extract":
			result, err = binds.Extract(ctx, o)
		case "remove":
			sites, perr := jsonx.Unmarshal(p.Sites)
			list, ok := jsonx.AsArray(sites)
			if perr != nil || !ok {
				return nil, axerr.New(axerr.BadRequest, "sites must be a list")
			}
			result, err = binds.Remove(ctx, o, list)
		default:
			return nil, axerr.New(axerr.BadRequest, "unknown bind merge verb %q", p.Verb)
		}
		if err != nil {
			return nil, err
		}
		return jsonx.MarshalCompact(result), nil
	})
}
