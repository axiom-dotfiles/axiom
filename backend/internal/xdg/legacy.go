package xdg

import (
	"errors"
	"fmt"
	"io/fs"
	"os"
	"path/filepath"
	"strings"
	"time"

	"github.com/axiom-shell/axiom/backend/internal/fsx"
)

// MovedMarker, in an old install's config folder, says its contents were
// copied to the XDG folders.
const MovedMarker = "MOVED.md"

// legacyPairs are an old install's folders inside its repo (tree) and the
// XDG folders their contents belong in, inner folders first so a folder
// inside another is copied by its own pair.
func legacyPairs(tree string, d Dirs) [][2]string {
	return [][2]string{
		{filepath.Join(tree, "config/state/notes"), d.Notes},
		{filepath.Join(tree, "config/themes/generated"), d.GeneratedThemes},
		{filepath.Join(tree, "config/state"), d.UI},
		{filepath.Join(tree, "config/user"), d.Config},
	}
}

// MoveLegacy copies an install from before the XDG folders (its config
// and state inside the repo) out to them, once: nothing is overwritten,
// config.json goes last and whole, then MOVED.md in the old config folder
// says where everything went. The old folders are kept (an older axiom
// still reads them). It returns whether there was anything to move.
func MoveLegacy(tree string, d Dirs, now time.Time) (bool, error) {
	pairs := legacyPairs(tree, d)
	oldConfig := pairs[len(pairs)-1][0]
	if _, err := os.Stat(filepath.Join(oldConfig, "config.json")); err != nil {
		return false, nil
	}
	if _, err := os.Stat(filepath.Join(oldConfig, MovedMarker)); err == nil {
		return false, nil
	}
	sources := map[string]bool{}
	for _, p := range pairs {
		sources[p[0]] = true
	}
	var configFrom, configTo string
	for _, p := range pairs {
		src, dst := p[0], p[1]
		entries, err := os.ReadDir(src)
		if errors.Is(err, fs.ErrNotExist) {
			continue
		}
		if err != nil {
			return true, err
		}
		if err := os.MkdirAll(dst, 0o700); err != nil {
			return true, err
		}
		for _, e := range entries {
			from := filepath.Join(src, e.Name())
			if sources[from] || e.Name() == MovedMarker {
				continue
			}
			if e.Name() == "config.json" && e.Type().IsRegular() {
				configFrom, configTo = from, filepath.Join(dst, "config.json")
				continue
			}
			if err := copyNew(from, filepath.Join(dst, e.Name())); err != nil {
				return true, err
			}
		}
	}
	// Last, whole: a copy cut short never leaves part of a config.json
	if configFrom != "" {
		if _, err := os.Lstat(configTo); errors.Is(err, fs.ErrNotExist) {
			data, err := os.ReadFile(configFrom)
			if err != nil {
				return true, err
			}
			if err := fsx.WriteFile(configTo, data, 0o600); err != nil {
				return true, err
			}
		}
	}
	var note strings.Builder
	fmt.Fprintf(&note, "# Moved\n\naxiom now keeps its config and state in the XDG folders. These were copied there on %s:\n\n", now.Format("2006-01-02"))
	for _, p := range pairs {
		fmt.Fprintf(&note, "- `%s/` → `%s`\n", p[0], p[1])
	}
	note.WriteString("\nThe copies here are no longer read (only an older axiom would read them) and can be deleted.\n")
	return true, fsx.WriteFile(filepath.Join(oldConfig, MovedMarker), []byte(note.String()), 0o644)
}

// copyNew copies a file or folder to dst, never over anything there, and
// never following a symlink (it's copied as one).
func copyNew(src, dst string) error {
	info, err := os.Lstat(src)
	if err != nil {
		return err
	}
	if _, err := os.Lstat(dst); err == nil {
		if info.IsDir() {
			return copyChildren(src, dst)
		}
		return nil
	}
	switch {
	case info.Mode()&fs.ModeSymlink != 0:
		target, err := os.Readlink(src)
		if err != nil {
			return err
		}
		return os.Symlink(target, dst)
	case info.IsDir():
		if err := os.Mkdir(dst, info.Mode().Perm()|0o700); err != nil {
			return err
		}
		return copyChildren(src, dst)
	case info.Mode().IsRegular():
		data, err := os.ReadFile(src)
		if err != nil {
			return err
		}
		return fsx.WriteFile(dst, data, info.Mode().Perm())
	}
	return nil // a socket or device: not ours to copy
}

func copyChildren(src, dst string) error {
	entries, err := os.ReadDir(src)
	if err != nil {
		return err
	}
	for _, e := range entries {
		if err := copyNew(filepath.Join(src, e.Name()), filepath.Join(dst, e.Name())); err != nil {
			return err
		}
	}
	return nil
}
