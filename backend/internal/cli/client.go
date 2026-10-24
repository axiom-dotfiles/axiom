package cli

import (
	"context"
	"os"
	"path/filepath"
	"time"

	"github.com/axiom-shell/axiom/backend/internal/axerr"
	"github.com/axiom-shell/axiom/backend/internal/buildinfo"
	"github.com/axiom-shell/axiom/backend/internal/daemon"
	"github.com/axiom-shell/axiom/backend/internal/rpc"
	"github.com/axiom-shell/axiom/backend/internal/xdg"
)

// socketPath is the daemon to talk to: --socket, else $AXIOM_SOCKET (set
// in the shell, so what it launches finds its daemon), else the one of
// $WAYLAND_DISPLAY, else the only one running.
func socketPath(e *Env) (string, error) {
	if e.Globals.Socket != "" {
		return e.Globals.Socket, nil
	}
	if s := e.Getenv("AXIOM_SOCKET"); s != "" {
		return s, nil
	}
	if xdg.DisplayName(e.Getenv("WAYLAND_DISPLAY")) != "" {
		rt, err := xdg.ForDisplay(e.Getenv, false)
		if err != nil {
			return "", axerr.Wrap(axerr.Unavailable, err, "no axiom runs on this display")
		}
		return rt.Socket(), nil
	}
	root, err := xdg.RuntimeRoot(e.Getenv, false)
	if err != nil {
		return "", axerr.Wrap(axerr.Unavailable, err, "no axiom is running")
	}
	matches, _ := filepath.Glob(filepath.Join(root, "*", "axiom.sock"))
	switch len(matches) {
	case 0:
		return "", axerr.New(axerr.Unavailable, "no axiom is running")
	case 1:
		return matches[0], nil
	}
	return "", axerr.New(axerr.BadRequest, "axiom runs on several displays: pick one with --socket or $WAYLAND_DISPLAY")
}

// connect dials the daemon and says hello.
func connect(ctx context.Context, e *Env) (*rpc.Conn, daemon.HelloResult, error) {
	path, err := socketPath(e)
	if err != nil {
		return nil, daemon.HelloResult{}, err
	}
	dctx, cancel := context.WithTimeout(ctx, 5*time.Second)
	defer cancel()
	c, err := rpc.Dial(dctx, path, nil, nil)
	if err != nil {
		return nil, daemon.HelloResult{}, err
	}
	var hello daemon.HelloResult
	if err := c.Call(dctx, "daemon.hello", daemon.HelloParams{Protocol: buildinfo.Protocol(), Client: "cli", PID: os.Getpid()}, &hello); err != nil {
		c.Close()
		return nil, daemon.HelloResult{}, err
	}
	return c, hello, nil
}

// call runs one request against the daemon.
func call(ctx context.Context, e *Env, method string, params, result any) error {
	c, _, err := connect(ctx, e)
	if err != nil {
		return err
	}
	defer c.Close()
	return c.Call(ctx, method, params, result)
}
