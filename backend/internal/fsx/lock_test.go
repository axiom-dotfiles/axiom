package fsx

import (
	"context"
	"os"
	"path/filepath"
	"testing"
	"time"

	"golang.org/x/sys/unix"
)

// A lock adopted across an exec (inherited without close-on-exec) gets
// close-on-exec back, so the children started after don't hold it.
func TestAdoptSetsCloseOnExec(t *testing.T) {
	t.Parallel()
	path := filepath.Join(t.TempDir(), "daemon.lock")
	l, err := TryLock(path)
	if err != nil {
		t.Fatal(err)
	}
	defer l.Release()
	fd := int(l.File().Fd())
	if _, err := unix.FcntlInt(uintptr(fd), unix.F_SETFD, 0); err != nil {
		t.Fatal(err)
	}
	adopted, err := Adopt(l.File(), path)
	if err != nil {
		t.Fatal(err)
	}
	flags, err := unix.FcntlInt(uintptr(int(adopted.File().Fd())), unix.F_GETFD, 0)
	if err != nil || flags&unix.FD_CLOEXEC == 0 {
		t.Errorf("flags %#x err %v: close-on-exec not set", flags, err)
	}
}

func TestLockDirWaitsForTheHolder(t *testing.T) {
	t.Parallel()
	dir := t.TempDir()
	l, err := LockDir(context.Background(), dir)
	if err != nil {
		t.Fatal(err)
	}
	// Held (another descriptor counts as another holder): a second waits,
	// until its context ends
	ctx, cancel := context.WithTimeout(context.Background(), 200*time.Millisecond)
	defer cancel()
	if _, err := LockDir(ctx, dir); err == nil {
		t.Fatal("locked twice")
	}
	got := make(chan error, 1)
	go func() {
		l2, err := LockDir(context.Background(), dir)
		l2.Release()
		got <- err
	}()
	time.Sleep(100 * time.Millisecond)
	l.Release()
	select {
	case err := <-got:
		if err != nil {
			t.Fatal(err)
		}
	case <-time.After(3 * time.Second):
		t.Fatal("never got the lock once released")
	}
	// Nothing was added to the folder
	if entries, _ := os.ReadDir(dir); len(entries) != 0 {
		t.Fatalf("left %v", entries)
	}
}
