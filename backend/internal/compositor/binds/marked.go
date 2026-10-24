package binds

import (
	"os"
	"path/filepath"
	"sort"
	"strings"

	"github.com/axiom-shell/axiom/backend/internal/compositor/edit"
	"github.com/axiom-shell/axiom/backend/internal/jsonx"
)

// What comments a moved bind out
const (
	swayMark = "# (moved into axiom) "
	// KDL's /- takes the whole node out, its block too
	niriMark = "/* (moved into axiom) */ /-"
)

// removeMarked comments the sites' lines out (sway's, niri's): the mark at
// the line's start, or at the bind's column (atCol), after a dated backup
// of each file it changes in user/.backups/ (a backup beside it in user/
// would be loaded by the managed config's include of user/). A line that
// changed since extract is left.
func removeMarked(o Options, sites *jsonx.Array, mark string, atCol bool) (*jsonx.Object, error) {
	done := jsonx.Obj("removed", float64(0), "files", jsonx.Arr(), "failed", jsonx.Arr())
	user := filepath.Join(o.Dir, "user")
	var files []string
	byFile := map[string][]site{}
	for _, s := range readSites(sites) {
		if _, ok := byFile[s.file]; !ok {
			files = append(files, s.file)
		}
		byFile[s.file] = append(byFile[s.file], s)
	}
	removed := 0
	for _, name := range files {
		if filepath.Dir(filepath.Clean(name)) != filepath.Clean(user) || !isFile(name) {
			push(done, "failed", failedEntry(name, 0, "notUser", ""))
			continue
		}
		data, err := os.ReadFile(name)
		if err != nil {
			return nil, err
		}
		lines := splitKeepEnds(strings.ToValidUTF8(string(data), "�"))
		fileSites := byFile[name]
		if atCol {
			// Right to left, so a column still points where it did
			sort.SliceStable(fileSites, func(i, j int) bool {
				a, b := fileSites[i], fileSites[j]
				return a.line > b.line || (a.line == b.line && a.col > b.col)
			})
		}
		changed := false
		for _, s := range fileSites {
			i := s.line - 1
			if i < 0 || i >= len(lines) || (s.hasText && strings.TrimRight(lines[i], "\r\n") != s.text) {
				push(done, "failed", failedEntry(name, s.line, "changed", ""))
				continue
			}
			if atCol {
				r := []rune(lines[i])
				col := min(max(s.col, 0), len(r))
				lines[i] = string(r[:col]) + mark + string(r[col:])
			} else {
				lines[i] = mark + lines[i]
			}
			removed++
			changed = true
		}
		if !changed {
			continue
		}
		backups := filepath.Join(user, ".backups")
		if err := os.MkdirAll(backups, 0o755); err != nil {
			return nil, err
		}
		if err := backup(o, name, backups); err != nil {
			return nil, err
		}
		if err := edit.Replace(name, []byte(strings.Join(lines, ""))); err != nil {
			return nil, err
		}
		push(done, "files", name)
	}
	done.Set("removed", float64(removed))
	return done, nil
}

// splitKeepEnds splits text into lines that keep their \n, \r\n or \r
// (str.splitlines(keepends=True))
func splitKeepEnds(text string) []string {
	var lines []string
	start := 0
	for i := 0; i < len(text); i++ {
		switch text[i] {
		case '\n':
			lines = append(lines, text[start:i+1])
			start = i + 1
		case '\r':
			if i+1 < len(text) && text[i+1] == '\n' {
				i++
			}
			lines = append(lines, text[start:i+1])
			start = i + 1
		}
	}
	if start < len(text) {
		lines = append(lines, text[start:])
	}
	return lines
}
