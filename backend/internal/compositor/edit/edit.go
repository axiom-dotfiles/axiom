// Package edit is how axiom changes a user's compositor files (the
// takeover's copies, the bind merge's edits): atomic replacement keeping a
// file's mode, and dated backups that keep its mode and modification time.
package edit

import (
	"os"

	"github.com/axiom-shell/axiom/backend/internal/fsx"
)

// Stamp is the layout of the dates in backup names (20261024-120000).
const Stamp = "20060102-150405"

// Replace replaces path's content atomically, keeping its mode (a new file
// gets 0644). A symlink is written through, so a file kept in a dotfiles
// repo stays there.
func Replace(path string, data []byte) error {
	return fsx.WriteFile(path, data, 0o644)
}

// WriteMode replaces path atomically, leaving it with mode.
func WriteMode(path string, data []byte, mode os.FileMode) error {
	if err := fsx.WriteFile(path, data, mode); err != nil {
		return err
	}
	return os.Chmod(path, mode)
}

// Copy copies src to dst with its mode and modification time (cp -p).
func Copy(src, dst string) error {
	data, err := os.ReadFile(src)
	if err != nil {
		return err
	}
	info, err := os.Stat(src)
	if err != nil {
		return err
	}
	if err := WriteMode(dst, data, info.Mode().Perm()); err != nil {
		return err
	}
	return os.Chtimes(dst, info.ModTime(), info.ModTime())
}
