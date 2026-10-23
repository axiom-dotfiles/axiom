package daemon

import (
	"context"
	"encoding/json"
	"io/fs"
	"net"
	"os"
	"path/filepath"
	"strings"
	"syscall"
	"time"

	"github.com/fsnotify/fsnotify"
	"golang.org/x/sys/unix"

	"github.com/axiom-shell/axiom/backend/internal/axerr"
	"github.com/axiom-shell/axiom/backend/internal/buildinfo"
	"github.com/axiom-shell/axiom/backend/internal/config"
	"github.com/axiom-shell/axiom/backend/internal/fsx"
	"github.com/axiom-shell/axiom/backend/internal/jsonx"
	"github.com/axiom-shell/axiom/backend/internal/schema"
	"github.com/axiom-shell/axiom/backend/internal/tree"
)

// reexecEnv carries a handoff from the image before a re-exec (an updated
// binary taking over) to the one after: the descriptors it keeps open and
// the shell it supervises (still this process's child: execve keeps the
// pid). The handoff is trusted only when its instance-lock descriptor
// really is the held lock of this display, which only the previous holder
// could pass on.
const reexecEnv = "AXIOM_REEXEC"

type handoff struct {
	Lock       int `json:"lock"`
	ConfigLock int `json:"configLock"`
	Listener   int `json:"listener"`
	Shell      int `json:"shell"`
}

// inherited reads (and clears) a handoff from the environment.
func inherited(getenv func(string) string) (*handoff, error) {
	raw := getenv(reexecEnv)
	if raw == "" {
		return nil, nil
	}
	os.Unsetenv(reexecEnv)
	var h handoff
	if err := json.Unmarshal([]byte(raw), &h); err != nil || h.Lock < 3 || h.Listener < 3 || h.ConfigLock < 3 {
		return nil, axerr.New(axerr.Refused, "a malformed %s", reexecEnv)
	}
	return &h, nil
}

// reexec replaces this process with the binary at its path, keeping the
// locks, the socket and the shell. Clients see their connection close and
// reconnect.
func (d *Daemon) reexec() error {
	exe := d.executable
	if _, err := os.Stat(exe); err != nil {
		return axerr.Wrap(axerr.Unavailable, err, "the binary to re-exec")
	}
	lf, ok := d.listener.(*net.UnixListener)
	if !ok {
		return axerr.New(axerr.Internal, "the socket can't be handed over")
	}
	listener, err := lf.File() // a duplicate, without close-on-exec once cleared
	if err != nil {
		return err
	}
	h := handoff{
		Lock:       int(d.instance.File().Fd()),
		ConfigLock: int(d.store.LockFile().Fd()),
		Listener:   int(listener.Fd()),
		Shell:      d.shellPID(),
	}
	for _, fd := range []int{h.Lock, h.ConfigLock, h.Listener} {
		if _, err := unix.FcntlInt(uintptr(fd), unix.F_SETFD, 0); err != nil {
			return axerr.Wrap(axerr.Internal, err, "keeping a descriptor across the re-exec")
		}
	}
	data, _ := json.Marshal(h)
	env := []string{reexecEnv + "=" + string(data)}
	for _, kv := range os.Environ() {
		if !strings.HasPrefix(kv, reexecEnv+"=") {
			env = append(env, kv)
		}
	}
	// No config write may be cut in half: hold the store until the exec
	d.store.Freeze()
	d.opts.Log.Info("re-executing", "binary", exe, "shell", h.Shell)
	return syscall.Exec(exe, os.Args, env)
}

// adopt takes the handoff's descriptors over.
func (d *Daemon) adopt(h *handoff) (net.Listener, error) {
	instance, err := fsx.Adopt(os.NewFile(uintptr(h.Lock), "daemon.lock"), d.runtime.Lock())
	if err != nil {
		return nil, err
	}
	d.instance = instance
	ln, err := net.FileListener(os.NewFile(uintptr(h.Listener), "axiom.sock"))
	if err != nil {
		return nil, axerr.Wrap(axerr.Refused, err, "the inherited socket")
	}
	if ul, ok := ln.(*net.UnixListener); ok {
		ul.SetUnlinkOnClose(true)
	}
	return ln, nil
}

// watchSchema (--dev) rebuilds the schema whenever its YAML source
// changes: written for the shell and the tools, the config loaded again
// through it, and schema.changed pushed so the shell reads it.
func (d *Daemon) watchSchema(ctx context.Context) error {
	w, err := fsnotify.NewWatcher()
	if err != nil {
		return err
	}
	defer w.Close()
	src := filepath.Join(d.opts.Tree, tree.SchemaSource)
	add := func() {
		filepath.WalkDir(src, func(p string, e fs.DirEntry, err error) error {
			if err == nil && e.IsDir() {
				w.Add(p)
			}
			return nil
		})
	}
	add()
	var timer *time.Timer
	fire := make(chan struct{}, 1)
	for {
		select {
		case <-ctx.Done():
			return nil
		case ev, ok := <-w.Events:
			if !ok {
				return nil
			}
			if ev.Has(fsnotify.Create) {
				add() // a new folder of definitions
			}
			if !strings.HasSuffix(ev.Name, ".yaml") {
				continue
			}
			if timer == nil {
				timer = time.AfterFunc(100*time.Millisecond, func() { fire <- struct{}{} })
			} else {
				timer.Reset(100 * time.Millisecond)
			}
		case <-w.Errors:
		case <-fire:
			d.rebuildSchema()
		}
	}
}

func (d *Daemon) rebuildSchema() {
	data, err := tree.BuildSchema(d.opts.Tree)
	if err != nil {
		d.opts.Log.Error("the schema source doesn't build: keeping the last one", "err", err)
		d.server.Broadcast("schema.error", map[string]any{"message": err.Error(), "issues": axerr.IssuesOf(err)}, subscribed)
		return
	}
	hash := buildinfo.SchemaHash(data)
	if hash == d.schemaHash {
		return
	}
	parsed, err := jsonx.Unmarshal(data)
	if err != nil {
		return
	}
	if err := fsx.WriteFile(d.runtime.File(SchemaFile), data, 0o600); err != nil {
		d.opts.Log.Error("writing the schema", "err", err)
		return
	}
	// The tree's generated copy too, for the tools and tests
	fsx.WriteFile(filepath.Join(d.opts.Tree, tree.SchemaJSON), data, 0o644)
	d.schemaBytes, d.schemaHash = data, hash
	d.store.Reschema(config.LegacyPipeline{S: schema.New(parsed)})
	d.opts.Log.Info("rebuilt the schema", "hash", hash)
	d.server.Broadcast("schema.changed", map[string]string{"hash": hash, "path": d.runtime.File(SchemaFile)}, subscribed)
}

// watchBinary (--dev) re-execs when the binary is rebuilt, so `go build`
// is the whole loop: the shell keeps running.
func (d *Daemon) watchBinary(ctx context.Context) error {
	w, err := fsnotify.NewWatcher()
	if err != nil {
		return err
	}
	defer w.Close()
	if err := w.Add(filepath.Dir(d.executable)); err != nil {
		return err
	}
	before, _ := os.Stat(d.executable)
	var timer *time.Timer
	fire := make(chan struct{}, 1)
	for {
		select {
		case <-ctx.Done():
			return nil
		case ev, ok := <-w.Events:
			if !ok {
				return nil
			}
			if ev.Name != d.executable {
				continue
			}
			if timer == nil {
				timer = time.AfterFunc(500*time.Millisecond, func() { fire <- struct{}{} })
			} else {
				timer.Reset(500 * time.Millisecond)
			}
		case <-w.Errors:
		case <-fire:
			now, err := os.Stat(d.executable)
			if err != nil || now.Mode()&0o111 == 0 || (before != nil && os.SameFile(before, now) && now.ModTime().Equal(before.ModTime())) {
				continue
			}
			if err := d.reexec(); err != nil {
				d.opts.Log.Error("re-exec", "err", err)
			}
		}
	}
}
