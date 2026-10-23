// Package daemon is `axiom run`: the parent of the shell. It takes the
// display's instance lock, builds the schema from the tree, opens the
// config, hands the shell both as files in the runtime directory (so the
// shell reads its config at once, already normalized), serves the socket,
// and supervises quickshell.
package daemon

import (
	"context"
	"errors"
	"io"
	"log/slog"
	"net"
	"os"
	"path/filepath"
	"strconv"
	"sync"
	"time"

	"github.com/axiom-shell/axiom/backend/internal/assets"
	"github.com/axiom-shell/axiom/backend/internal/axerr"
	"github.com/axiom-shell/axiom/backend/internal/buildinfo"
	"github.com/axiom-shell/axiom/backend/internal/config"
	"github.com/axiom-shell/axiom/backend/internal/fsx"
	"github.com/axiom-shell/axiom/backend/internal/ipcroute"
	"github.com/axiom-shell/axiom/backend/internal/jsonx"
	"github.com/axiom-shell/axiom/backend/internal/lock"
	"github.com/axiom-shell/axiom/backend/internal/rpc"
	"github.com/axiom-shell/axiom/backend/internal/saved"
	"github.com/axiom-shell/axiom/backend/internal/schema"
	"github.com/axiom-shell/axiom/backend/internal/store"
	"github.com/axiom-shell/axiom/backend/internal/supervise"
	"github.com/axiom-shell/axiom/backend/internal/tree"
	"github.com/axiom-shell/axiom/backend/internal/wayland/wire"
	"github.com/axiom-shell/axiom/backend/internal/xdg"
)

// Options configure a daemon.
type Options struct {
	Tree    string // the axiom tree the shell runs from
	Dev     bool   // the tree's schema may differ from the binary's
	NoShell bool   // don't start quickshell (tests, headless use)
	QS      string // the quickshell binary (default "qs")
	Getenv  func(string) string
	Log     *slog.Logger
	// ShellOutput gets the shell's stdout and stderr (nil: discarded)
	ShellOutput io.Writer
}

// Files in the runtime directory
const (
	SchemaFile   = "config.schema.json" // the schema, built from the tree
	SnapshotFile = "config.json"        // the config, normalized, for the shell's first read
	ShellPIDFile = "shell.pid"
)

// Daemon is a running daemon.
type Daemon struct {
	opts    Options
	runtime xdg.Runtime
	dirs    xdg.Dirs
	started time.Time

	schemaBytes []byte
	schemaHash  string
	compatible  bool   // the tree's schema is the one this binary was built with
	reason      string // why not

	executable string // this binary, for a re-exec
	instance   *fsx.Lock
	listener   net.Listener

	store  *store.Store
	saved  *saved.Service
	server *rpc.Server
	shell  *supervise.Supervisor
	router *ipcroute.Router
	locker *lock.Locker
	stop   context.CancelFunc
}

// Run runs the daemon until ctx ends or it is told to shut down.
func Run(ctx context.Context, opts Options) error {
	if opts.Log == nil {
		opts.Log = slog.New(slog.DiscardHandler)
	}
	if opts.QS == "" {
		opts.QS = "qs"
	}
	runtime, err := xdg.ForDisplay(opts.Getenv, true)
	if err != nil {
		return err
	}
	d := &Daemon{opts: opts, runtime: runtime, dirs: xdg.Resolve(opts.Getenv), started: time.Now()}
	if d.executable, err = os.Executable(); err == nil {
		d.executable, _ = filepath.EvalSymlinks(d.executable)
	}
	h, err := inherited(opts.Getenv)
	if err != nil {
		return err
	}
	if h != nil {
		if d.listener, err = d.adopt(h); err != nil {
			return err
		}
	} else if d.instance, err = fsx.TryLock(runtime.Lock()); err != nil {
		if axerr.KindOf(err) == axerr.Running {
			return &axerr.Error{Kind: axerr.Running, Message: "axiom is already running on " + runtime.Display, Err: err}
		}
		return err
	}
	defer d.instance.Release()

	// An install from before the XDG folders: its config and state out of
	// the repo first, so the store finds them
	if moved, err := xdg.MoveLegacy(opts.Tree, d.dirs, time.Now()); err != nil {
		opts.Log.Error("moving the config out of the repo failed; starting on the XDG folders", "err", err)
	} else if moved {
		opts.Log.Info("moved the config and state out of the repo into the XDG folders", "config", d.dirs.Config)
	}
	if err := d.loadSchema(); err != nil {
		return err
	}
	parsed, err := jsonx.Unmarshal(d.schemaBytes)
	if err != nil {
		return axerr.Wrap(axerr.Internal, err, "the built schema")
	}
	storeOpts := store.Options{
		Dir:      d.dirs.Config,
		Pipeline: config.V2Pipeline{S: schema.New(parsed)},
		Log:      opts.Log.With("part", "config"),
	}
	if h != nil {
		d.store, err = store.OpenAdopting(storeOpts, os.NewFile(uintptr(h.ConfigLock), "config.json.lock"))
	} else {
		d.store, err = store.Open(storeOpts)
	}
	if err != nil {
		return err
	}
	defer d.store.Close()
	if err := d.writeSnapshot(); err != nil {
		return err
	}

	if d.listener == nil {
		if d.listener, err = rpc.Listen(runtime.Socket()); err != nil {
			return err
		}
	}
	ctx, d.stop = context.WithCancel(ctx)
	defer d.stop()
	d.router = ipcroute.New(ipcroute.Options{QS: opts.QS, ShellPID: d.shellPID})
	d.locker = lock.New(lock.Options{
		AskShell: func(ctx context.Context) error {
			_, err := d.router.Call(ctx, ipcroute.CallParams{Target: "lockscreen", Function: "lock"})
			return err
		},
		StartLocked: d.startLocked,
		Mode:        func() string { return d.lockSetting("mode") },
		Command:     func() string { return d.lockSetting("lockCommand") },
		Log:         opts.Log.With("part", "lock"),
	})
	d.saved = saved.New(saved.Options{
		Dir:      d.dirs.Config,
		Examples: filepath.Join(opts.Tree, "examples"),
		Home:     opts.Getenv("HOME"),
		UIState:  filepath.Join(d.dirs.UI, "savedconfigs.json"),
		Store:    d.store,
		Pipeline: d.store.Pipeline,
		Log:      opts.Log.With("part", "saved"),
		OnState: func(st saved.State) {
			if d.server != nil {
				d.server.Broadcast("saved.state", st, subscribed)
			}
		},
	})
	d.server = &rpc.Server{
		Registry: d.registry(),
		Log:      opts.Log.With("part", "rpc"),
		OnClose:  d.router.Forget,
	}
	d.store.Subscribe(d.onConfigEvent)

	var wg sync.WaitGroup
	serve := func(name string, fn func(context.Context) error) {
		wg.Add(1)
		go func() {
			defer wg.Done()
			if err := fn(ctx); err != nil {
				opts.Log.Error(name+" stopped", "err", err)
				d.stop()
			}
		}()
	}
	serve("the socket", func(ctx context.Context) error { return d.server.Serve(ctx, d.listener) })
	// Stop with the compositor: a daemon left over from a session that
	// ended would hold the display's lock, and the next session's
	// `axiom run` would find it taken
	if socket, err := wire.SocketPath(opts.Getenv); err != nil {
		opts.Log.Warn("not watching the compositor", "err", err)
	} else {
		serve("the compositor watch", func(ctx context.Context) error {
			err := wire.Watch(ctx, socket)
			if errors.Is(err, wire.ErrGone) {
				opts.Log.Info("the compositor is gone: stopping")
				d.stop()
				return nil
			}
			if err != nil {
				opts.Log.Warn("not watching the compositor", "err", err)
			}
			return nil
		})
	}
	serve("the config watch", d.store.Watch)
	if opts.Dev {
		serve("the schema watch", d.watchSchema)
		if d.executable != "" {
			serve("the binary watch", d.watchBinary)
		}
	}
	if !opts.NoShell {
		adopt := 0
		if h != nil {
			adopt = h.Shell
		}
		d.shell = supervise.New(supervise.Options{
			Command:  []string{opts.QS, "-p", opts.Tree},
			Env:      d.shellEnv(),
			PIDFile:  runtime.File(ShellPIDFile),
			Output:   opts.ShellOutput,
			Log:      opts.Log.With("part", "shell"),
			AdoptPID: adopt,
			OnExit:   func(int, bool) { d.locker.ShellExited() },
		})
		serve("the shell", d.shell.Run)
	}
	opts.Log.Info("axiom is running", "display", runtime.Display, "tree", opts.Tree, "socket", runtime.Socket(), "version", buildinfo.Get().Version, "reexec", h != nil)
	<-ctx.Done()
	wg.Wait()
	opts.Log.Info("axiom stopped")
	return nil
}

// loadSchema builds the tree's schema and writes it for the shell. A tree
// whose schema isn't the one this binary was built with is a different
// axiom: allowed with --dev, otherwise the shell is told why it can't save.
func (d *Daemon) loadSchema() error {
	data, err := tree.BuildSchema(d.opts.Tree)
	if err != nil {
		return err
	}
	d.schemaBytes = data
	d.schemaHash = buildinfo.SchemaHash(data)
	d.compatible = true
	if embedded, err := assets.Read("config/json/config.schema.json"); err == nil && buildinfo.SchemaHash(embedded) != d.schemaHash {
		if d.opts.Dev {
			d.opts.Log.Warn("the tree's schema isn't the one this binary was built with (fine with --dev)")
		} else {
			d.compatible = false
			d.reason = "this axiom binary was built for another version of the shell's files: update the binary"
			d.opts.Log.Error(d.reason, "tree", d.opts.Tree)
		}
	}
	return fsx.WriteFile(d.runtime.File(SchemaFile), data, 0o600)
}

func (d *Daemon) shellPID() int {
	if d.shell == nil {
		return 0
	}
	return d.shell.Status().PID
}

// startLocked (re)starts the shell so that it locks before anything else.
func (d *Daemon) startLocked(ctx context.Context) error {
	if d.shell == nil {
		return axerr.New(axerr.Unavailable, "this daemon runs no shell")
	}
	return d.shell.Restart(ctx, map[string]string{"AXIOM_LOCK_ON_START": "1"})
}

// lockSetting is a Lockscreen setting (mode, lockCommand).
func (d *Daemon) lockSetting(key string) string {
	cfg, _ := d.store.Config()
	v, _ := config.Lookup(cfg, config.Keys("Lockscreen", key))
	s, _ := v.(string)
	return s
}

// writeSnapshot writes the current config for the shell's first read.
func (d *Daemon) writeSnapshot() error {
	cfg, _ := d.store.Config()
	return fsx.WriteFile(d.runtime.File(SnapshotFile), jsonx.Marshal(cfg), 0o600)
}

func (d *Daemon) shellEnv() map[string]string {
	env := map[string]string{
		"AXIOM_SOCKET":     d.runtime.Socket(),
		"AXIOM_SCHEMA":     d.runtime.File(SchemaFile),
		"AXIOM_CONFIG":     d.runtime.File(SnapshotFile),
		"AXIOM_DAEMON_PID": itoa(os.Getpid()),
		"AXIOM_TREE":       d.opts.Tree,
		// What binds and generated compositor configs call
		"AXIOM_BIN": d.executable,
	}
	if !d.compatible {
		env["AXIOM_INCOMPATIBLE"] = d.reason
	}
	return env
}

// onConfigEvent pushes a config change to the subscribed connections and
// keeps the snapshot current.
func (d *Daemon) onConfigEvent(ev store.Event) {
	if ev.Config != nil {
		if err := d.writeSnapshot(); err != nil {
			d.opts.Log.Error("writing the config snapshot", "err", err)
		}
		d.server.Broadcast("config.changed", configChanged{Revision: ev.State.Revision, Config: rawJSON(ev.Config)}, subscribed)
	}
	d.server.Broadcast("config.state", ev.State, subscribed)
	// Whether the config still is its saved snapshot (an apply may hold
	// the service right now: not on this goroutine)
	go d.saved.Changed()
}

func itoa(n int) string { return strconv.Itoa(n) }
