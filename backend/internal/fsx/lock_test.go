package fsx

import (
	"path/filepath"
	"testing"

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
