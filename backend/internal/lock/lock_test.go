package lock

import (
	"context"
	"errors"
	"os"
	"path/filepath"
	"sync/atomic"
	"testing"
	"time"

	"github.com/axiom-shell/axiom/backend/internal/axerr"
)

func TestLockConfirmedByTheShell(t *testing.T) {
	t.Parallel()
	var l *Locker
	l = New(Options{
		Confirm:  time.Second,
		AskShell: func(ctx context.Context) error { go l.Report(State{Locked: true, Surfaces: 2, Outputs: 2}); return nil },
	})
	if err := l.Lock(context.Background()); err != nil {
		t.Fatal(err)
	}
	// Already locked: nothing asked again
	l.opts.AskShell = func(ctx context.Context) error { t.Error("asked again"); return nil }
	if err := l.Lock(context.Background()); err != nil {
		t.Fatal(err)
	}
}

func TestPartialLockIsNotConfirmed(t *testing.T) {
	t.Parallel()
	var started atomic.Bool
	var l *Locker
	l = New(Options{
		Confirm:  50 * time.Millisecond,
		AskShell: func(ctx context.Context) error { l.Report(State{Locked: true, Surfaces: 1, Outputs: 2}); return nil },
		StartLocked: func(ctx context.Context) error {
			started.Store(true)
			go l.Report(State{Locked: true, Surfaces: 2, Outputs: 2})
			return nil
		},
	})
	if err := l.Lock(context.Background()); err != nil {
		t.Fatal(err)
	}
	if !started.Load() {
		t.Error("a lock missing an output counted as locked")
	}
}

func TestBuiltinLockerNeverFallsBackToACommand(t *testing.T) {
	t.Parallel()
	marker := filepath.Join(t.TempDir(), "ran")
	l := New(Options{
		Confirm:     20 * time.Millisecond,
		AskShell:    func(ctx context.Context) error { return errors.New("no shell") },
		StartLocked: func(ctx context.Context) error { return nil },
		Mode:        func() string { return "quickshell" },
		Command:     func() string { return "touch " + marker },
	})
	if err := l.Lock(context.Background()); axerr.KindOf(err) != axerr.Unavailable {
		t.Fatalf("an unconfirmed lock succeeded: %v", err)
	}
	time.Sleep(50 * time.Millisecond)
	if _, err := os.Stat(marker); err == nil {
		t.Error("ran a command while the built-in locker is in charge")
	}
}

func TestOwnLockerRunsItsCommandButNotLoginctl(t *testing.T) {
	t.Parallel()
	marker := filepath.Join(t.TempDir(), "ran")
	command := "touch " + marker
	l := New(Options{Mode: func() string { return "none" }, Command: func() string { return command }})
	if err := l.Lock(context.Background()); err != nil {
		t.Fatal(err)
	}
	for i := 0; i < 50; i++ {
		if _, err := os.Stat(marker); err == nil {
			break
		}
		time.Sleep(10 * time.Millisecond)
	}
	if _, err := os.Stat(marker); err != nil {
		t.Error("the lock command didn't run")
	}
	command = "loginctl lock-session"
	if err := l.Lock(context.Background()); err == nil {
		t.Error("loginctl lock-session (which loops back to axiom) was run")
	}
}

func TestNoWayToLockFails(t *testing.T) {
	t.Parallel()
	l := New(Options{Confirm: 10 * time.Millisecond})
	if err := l.Lock(context.Background()); err == nil {
		t.Error("succeeded with nothing to lock with")
	}
}

func TestShellDyingWhileLockedRelocks(t *testing.T) {
	t.Parallel()
	restarted := make(chan struct{}, 1)
	l := New(Options{StartLocked: func(ctx context.Context) error { restarted <- struct{}{}; return nil }})
	l.Report(State{Locked: true, Surfaces: 1, Outputs: 1})
	l.ShellExited()
	select {
	case <-restarted:
	case <-time.After(time.Second):
		t.Fatal("not restarted locked")
	}
	if l.State().confirmed() {
		t.Error("still confirmed with the shell gone")
	}
	// Unlocked, an exit is just an exit
	l.Report(State{Locked: false})
	l.ShellExited()
	select {
	case <-restarted:
		t.Error("restarted locked while unlocked")
	case <-time.After(50 * time.Millisecond):
	}
}
