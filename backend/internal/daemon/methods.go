package daemon

import (
	"context"
	"encoding/json"
	"os"
	"time"

	"github.com/axiom-shell/axiom/backend/internal/axerr"
	"github.com/axiom-shell/axiom/backend/internal/buildinfo"
	"github.com/axiom-shell/axiom/backend/internal/config"
	"github.com/axiom-shell/axiom/backend/internal/ipcroute"
	"github.com/axiom-shell/axiom/backend/internal/jsonx"
	"github.com/axiom-shell/axiom/backend/internal/lock"
	"github.com/axiom-shell/axiom/backend/internal/rpc"
	"github.com/axiom-shell/axiom/backend/internal/saved"
	"github.com/axiom-shell/axiom/backend/internal/share"
	"github.com/axiom-shell/axiom/backend/internal/store"
	"github.com/axiom-shell/axiom/backend/internal/supervise"
	"github.com/axiom-shell/axiom/backend/internal/xdg"
)

// session is what the daemon knows of one connection.
type session struct {
	Client     string // "shell", "cli"
	Subscribed bool   // gets config.changed / config.state
	PID        int
}

type sessionKey struct{}

func sessionOf(c *rpc.Conn) *session {
	v, ok := c.Value(sessionKey{})
	if !ok {
		return nil
	}
	return v.(*session)
}

// fromShell: the connection is the shell's (it said so in hello, and runs
// as the daemon's child)
func fromShell(c *rpc.Conn) bool {
	s := sessionOf(c)
	return s != nil && s.Client == "shell"
}

func subscribed(c *rpc.Conn) bool {
	s := sessionOf(c)
	return s != nil && s.Subscribed
}

// HelloParams open a session. The protocol must be this binary's; a client
// that read a schema says which (its md5), and must have read this one.
type HelloParams struct {
	Protocol   int    `json:"protocol"`
	Client     string `json:"client"`
	SchemaHash string `json:"schemaHash,omitempty"`
	Subscribe  bool   `json:"subscribe"`
	PID        int    `json:"pid"`
}

// HelloResult describes the daemon to a client.
type HelloResult struct {
	Protocol   int         `json:"protocol"`
	Version    string      `json:"version"`
	Commit     string      `json:"commit"`
	SchemaHash string      `json:"schemaHash"`
	PID        int         `json:"pid"`
	Display    string      `json:"display"`
	Tree       string      `json:"tree"`
	Dirs       xdg.Dirs    `json:"dirs"`
	State      store.State `json:"state"`
	// Compatible is false when the tree's schema isn't this binary's (the
	// shell then runs read-only and says why)
	Compatible bool   `json:"compatible"`
	Reason     string `json:"reason,omitempty"`
}

// StatusResult is daemon.status.
type StatusResult struct {
	HelloResult
	Uptime  string            `json:"uptime"`
	Shell   *supervise.Status `json:"shell,omitempty"`
	Clients int               `json:"clients"`
}

type configResult struct {
	Revision int64           `json:"revision"`
	Config   json.RawMessage `json:"config"`
	State    store.State     `json:"state"`
}

type configChanged struct {
	Revision int64           `json:"revision"`
	Config   json.RawMessage `json:"config"`
}

type setParams struct {
	Ops      []config.Op `json:"ops"`
	Takeover bool        `json:"takeover"`
}

type restoreParams struct {
	Config   json.RawMessage `json:"config"`
	Takeover bool            `json:"takeover"`
}

type revisionResult struct {
	Revision int64 `json:"revision"`
}

func rawJSON(v any) json.RawMessage { return json.RawMessage(jsonx.MarshalCompact(v)) }

func (d *Daemon) registry() *rpc.Registry {
	reg := rpc.NewRegistry()
	reg.Before = func(c *rpc.Conn, method string) error {
		if method != "daemon.hello" && sessionOf(c) == nil {
			return axerr.New(axerr.BadRequest, "say daemon.hello first")
		}
		return nil
	}

	rpc.Handle(reg, "daemon.hello", func(ctx context.Context, c *rpc.Conn, p HelloParams) (HelloResult, error) {
		if p.Protocol != buildinfo.Protocol() {
			return HelloResult{}, axerr.New(axerr.Incompatible, "this axiom speaks protocol %d, the client %d: the shell's files and the binary are from different versions", buildinfo.Protocol(), p.Protocol)
		}
		if _, hash := d.currentSchema(); p.SchemaHash != "" && p.SchemaHash != hash {
			return HelloResult{}, axerr.New(axerr.Incompatible, "the client read another schema than the daemon built (restart the shell)")
		}
		c.SetValue(sessionKey{}, &session{Client: p.Client, Subscribed: p.Subscribe, PID: p.PID})
		return d.hello(), nil
	})

	rpc.Handle(reg, "daemon.status", func(ctx context.Context, c *rpc.Conn, _ struct{}) (StatusResult, error) {
		res := StatusResult{HelloResult: d.hello(), Uptime: time.Since(d.started).Round(time.Second).String(), Clients: len(d.server.Conns())}
		if d.shell != nil {
			st := d.shell.Status()
			res.Shell = &st
		}
		return res, nil
	})

	rpc.Handle(reg, "daemon.shutdown", func(ctx context.Context, c *rpc.Conn, _ struct{}) (struct{}, error) {
		d.opts.Log.Info("asked to shut down", "client", sessionOf(c).Client)
		go d.stop()
		return struct{}{}, nil
	})

	rpc.Handle(reg, "daemon.reexec", func(ctx context.Context, c *rpc.Conn, _ struct{}) (struct{}, error) {
		// Replies first: the exec closes every connection
		go func() {
			time.Sleep(50 * time.Millisecond)
			if err := d.reexec(); err != nil {
				d.opts.Log.Error("re-exec", "err", err)
			}
		}()
		return struct{}{}, nil
	})

	rpc.Handle(reg, "shell.restart", func(ctx context.Context, c *rpc.Conn, _ struct{}) (struct{}, error) {
		if d.shell == nil {
			return struct{}{}, axerr.New(axerr.Unavailable, "this daemon runs no shell")
		}
		return struct{}{}, d.restartShell(ctx)
	})

	rpc.Handle(reg, "ipc.register", func(ctx context.Context, c *rpc.Conn, p struct {
		Targets []ipcroute.Target `json:"targets"`
	}) (struct{}, error) {
		if !fromShell(c) {
			return struct{}{}, axerr.New(axerr.Refused, "only the shell registers IPC targets")
		}
		names := make([]string, 0, len(p.Targets))
		for _, t := range p.Targets {
			names = append(names, t.Name)
		}
		// The functions and their types come from quickshell itself
		go func() {
			sigs, err := d.router.Signatures(context.Background())
			if err != nil {
				d.opts.Log.Warn("reading the shell's IPC functions (qs ipc show)", "err", err)
				return
			}
			d.router.RegisterNames(c, names, sigs)
			d.opts.Log.Debug("the shell registered its IPC targets", "targets", len(names))
		}()
		return struct{}{}, nil
	})

	rpc.Handle(reg, "ipc.call", func(ctx context.Context, c *rpc.Conn, p ipcroute.CallParams) (string, error) {
		// The lock screen goes through the locker, which confirms it: and
		// nothing but lock can be asked of it
		if p.Target == "lockscreen" {
			if p.Function != "lock" {
				return "", axerr.New(axerr.Refused, "the lock screen only takes lock (it unlocks with your password, never by request)")
			}
			return "", d.locker.Lock(ctx)
		}
		return d.router.Call(ctx, p)
	})

	rpc.Handle(reg, "ipc.list", func(ctx context.Context, c *rpc.Conn, _ struct{}) ([]ipcroute.Target, error) {
		return d.router.Targets(), nil
	})

	rpc.Handle(reg, "lock.lock", func(ctx context.Context, c *rpc.Conn, _ struct{}) (struct{}, error) {
		return struct{}{}, d.locker.Lock(ctx)
	})

	rpc.Handle(reg, "lock.state", func(ctx context.Context, c *rpc.Conn, p lock.State) (struct{}, error) {
		if !fromShell(c) {
			return struct{}{}, axerr.New(axerr.Refused, "only the shell reports the lock state")
		}
		d.locker.Report(p)
		return struct{}{}, nil
	})

	rpc.Handle(reg, "config.get", func(ctx context.Context, c *rpc.Conn, _ struct{}) (configResult, error) {
		cfg, st := d.store.Config()
		return configResult{Revision: st.Revision, Config: rawJSON(cfg), State: st}, nil
	})

	rpc.Handle(reg, "config.set", func(ctx context.Context, c *rpc.Conn, p setParams) (revisionResult, error) {
		if err := d.writable(); err != nil {
			return revisionResult{}, err
		}
		rev, err := d.store.Set(p.Ops, store.SetOptions{Takeover: p.Takeover})
		return revisionResult{Revision: rev}, err
	})

	// A whole config the shell's editors made (format 2): written as
	// config.set's ops would be
	rpc.Handle(reg, "config.replace", func(ctx context.Context, c *rpc.Conn, p restoreParams) (revisionResult, error) {
		if err := d.writable(); err != nil {
			return revisionResult{}, err
		}
		v, err := jsonx.Unmarshal(p.Config)
		obj, ok := v.(*jsonx.Object)
		if err != nil || !ok {
			return revisionResult{}, axerr.New(axerr.BadRequest, "config.replace takes a config object")
		}
		rev, err := d.store.Replace(obj, store.SetOptions{Takeover: p.Takeover})
		return revisionResult{Revision: rev}, err
	})

	// A config of any format axiom reads, put in place of the running one
	// (loaded as config.json is): it lifts a file that doesn't load
	rpc.Handle(reg, "config.restore", func(ctx context.Context, c *rpc.Conn, p restoreParams) (revisionResult, error) {
		if err := d.writable(); err != nil {
			return revisionResult{}, err
		}
		v, err := jsonx.Unmarshal(p.Config)
		if _, ok := v.(*jsonx.Object); err != nil || !ok {
			return revisionResult{}, axerr.New(axerr.BadRequest, "config.restore takes a config object")
		}
		rev, err := d.store.Restore(v, store.SetOptions{Takeover: p.Takeover})
		return revisionResult{Revision: rev}, err
	})

	rpc.Handle(reg, "config.ackFirstRun", func(ctx context.Context, c *rpc.Conn, _ struct{}) (struct{}, error) {
		d.store.AckFirstRun()
		return struct{}{}, nil
	})
	d.sharing(reg)
	return reg
}

// writable refuses writes from a binary built for another schema: it
// would validate the shell's edits against the wrong shape.
func (d *Daemon) writable() error {
	if !d.compatible {
		return axerr.New(axerr.Incompatible, "%s", d.reason)
	}
	return nil
}

func (d *Daemon) hello() HelloResult {
	info := buildinfo.Get()
	_, st := d.store.Config()
	_, hash := d.currentSchema()
	return HelloResult{
		Protocol: info.Protocol, Version: info.Version, Commit: info.Commit,
		SchemaHash: hash, PID: os.Getpid(), Display: d.runtime.Display,
		Tree: d.opts.Tree, Dirs: d.dirs, State: st,
		Compatible: d.compatible, Reason: d.reason,
	}
}

// sharedParams name what to apply, with this PC's outputs ({ name, x, y },
// as the shell has them: the daemon has no Wayland connection to ask yet),
// which shared files name by place
type sharedParams struct {
	Name     string          `json:"name"`
	Path     string          `json:"path"`
	Snapshot string          `json:"snapshot"`
	Personal bool            `json:"personal"`
	Commands bool            `json:"commands"`
	Places   bool            `json:"places"`
	Outputs  json.RawMessage `json:"outputs"`
}

// monitors are p's outputs by place (share.MonitorOrder), nil without any
func (p sharedParams) monitors() share.Monitors {
	if len(p.Outputs) == 0 {
		return nil
	}
	outputs, err := jsonx.Unmarshal(p.Outputs)
	if err != nil {
		return nil
	}
	out := share.Monitors{}
	for _, v := range share.MonitorOrder(outputs).Items {
		if name, ok := v.(string); ok {
			out = append(out, name)
		}
	}
	return out
}

// sharing: saved snapshots and shared configs (internal/saved), for the
// shell's settings page and the CLI.
func (d *Daemon) sharing(reg *rpc.Registry) {
	rpc.Handle(reg, "saved.list", func(ctx context.Context, c *rpc.Conn, _ struct{}) ([]saved.Entry, error) {
		return d.saved.List()
	})
	rpc.Handle(reg, "saved.state", func(ctx context.Context, c *rpc.Conn, _ struct{}) (saved.State, error) {
		return d.saved.State(), nil
	})
	rpc.Handle(reg, "saved.save", func(ctx context.Context, c *rpc.Conn, p sharedParams) (map[string]string, error) {
		name, err := d.saved.Save(p.Name, "")
		return map[string]string{"name": name}, err
	})
	rpc.Handle(reg, "saved.restore", func(ctx context.Context, c *rpc.Conn, p sharedParams) (struct{}, error) {
		if err := d.writable(); err != nil {
			return struct{}{}, err
		}
		return struct{}{}, d.saved.Restore(p.Name)
	})
	rpc.Handle(reg, "saved.remove", func(ctx context.Context, c *rpc.Conn, p sharedParams) (struct{}, error) {
		return struct{}{}, d.saved.Remove(p.Name)
	})
	rpc.Handle(reg, "share.examples", func(ctx context.Context, c *rpc.Conn, _ struct{}) ([]saved.Example, error) {
		return d.saved.Examples(), nil
	})
	rpc.Handle(reg, "share.open", func(ctx context.Context, c *rpc.Conn, p sharedParams) (saved.Preview, error) {
		return d.saved.Open(p.Path)
	})
	rpc.Handle(reg, "share.import", func(ctx context.Context, c *rpc.Conn, p sharedParams) (saved.Applied, error) {
		if err := d.writable(); err != nil {
			return saved.Applied{}, err
		}
		return d.saved.Import(p.Path, p.Personal, p.Commands, p.monitors())
	})
	rpc.Handle(reg, "share.example", func(ctx context.Context, c *rpc.Conn, p sharedParams) (saved.Applied, error) {
		if err := d.writable(); err != nil {
			return saved.Applied{}, err
		}
		return d.saved.ApplyExample(p.Name, p.monitors())
	})
	rpc.Handle(reg, "share.applyShared", func(ctx context.Context, c *rpc.Conn, p sharedParams) (saved.Applied, error) {
		if err := d.writable(); err != nil {
			return saved.Applied{}, err
		}
		return d.saved.ApplyShared(p.Path, p.Name, p.Snapshot, p.monitors())
	})
	rpc.Handle(reg, "share.defaults", func(ctx context.Context, c *rpc.Conn, _ struct{}) (saved.Applied, error) {
		if err := d.writable(); err != nil {
			return saved.Applied{}, err
		}
		return d.saved.Defaults()
	})
	rpc.Handle(reg, "share.export", func(ctx context.Context, c *rpc.Conn, p sharedParams) (map[string]string, error) {
		path, err := d.saved.Export(p.Personal, p.Commands, p.Places, p.monitors())
		return map[string]string{"path": path}, err
	})
}
