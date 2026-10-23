package store

import (
	"context"
	"os"
	"path/filepath"
	"strings"
	"sync"
	"testing"
	"time"

	"github.com/axiom-shell/axiom/backend/internal/axerr"
	"github.com/axiom-shell/axiom/backend/internal/config"
	"github.com/axiom-shell/axiom/backend/internal/jsonx"
	"github.com/axiom-shell/axiom/backend/internal/schema"
	"github.com/axiom-shell/axiom/backend/internal/testkit"
)

func pipeline(t *testing.T) config.Pipeline {
	t.Helper()
	root, err := testkit.Schema("legacy-v75")
	if err != nil {
		t.Fatal(err)
	}
	return config.LegacyPipeline{S: schema.New(root)}
}

func open(t *testing.T, dir string) *Store {
	t.Helper()
	s, err := Open(Options{Dir: dir, Pipeline: pipeline(t), Debounce: 20 * time.Millisecond})
	if err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() { s.Close() })
	return s
}

func TestFirstRunWritesDefaults(t *testing.T) {
	t.Parallel()
	dir := t.TempDir()
	s := open(t, dir)
	cfg, st := s.Config()
	if !st.FirstRun || cfg.Value("version") != 75.0 {
		t.Fatalf("state %+v", st)
	}
	data, _ := os.ReadFile(filepath.Join(dir, FileName))
	if !strings.HasSuffix(string(data), "}\n") {
		t.Error("not written canonically")
	}
	if info, _ := os.Stat(filepath.Join(dir, FileName)); info.Mode().Perm() != 0o600 {
		t.Errorf("mode %o", info.Mode().Perm())
	}
	s.AckFirstRun()
	if _, st := s.Config(); st.FirstRun {
		t.Error("first run not acknowledged")
	}
}

func TestOneWriterPerFolder(t *testing.T) {
	t.Parallel()
	dir := t.TempDir()
	open(t, dir)
	if _, err := Open(Options{Dir: dir, Pipeline: pipeline(t)}); axerr.KindOf(err) != axerr.Running {
		t.Errorf("second store: %v", err)
	}
}

func TestOldConfigMigratesAndIsWrittenBack(t *testing.T) {
	t.Parallel()
	dir := t.TempDir()
	os.WriteFile(filepath.Join(dir, FileName), []byte(`{"version": 74}`), 0o644)
	s := open(t, dir)
	cfg, _ := s.Config()
	if cfg.Value("version") != 75.0 {
		t.Errorf("version %v", cfg.Value("version"))
	}
	data, _ := os.ReadFile(filepath.Join(dir, FileName))
	if !strings.Contains(string(data), `"version": 75`) {
		t.Error("migration not written back")
	}
}

func TestSetValidatesAndRefusesTakeovers(t *testing.T) {
	t.Parallel()
	s := open(t, t.TempDir())
	var events []Event
	var mu sync.Mutex
	s.Subscribe(func(e Event) { mu.Lock(); events = append(events, e); mu.Unlock() })

	rev, err := s.Set([]config.Op{config.SetValue(config.Keys("Battery", "lowThreshold"), 15.0)}, SetOptions{})
	if err != nil || rev != 2 {
		t.Fatalf("set: %v rev %d", err, rev)
	}
	_, err = s.Set([]config.Op{config.SetValue(config.Keys("Battery", "lowThreshold"), "lots")}, SetOptions{})
	if axerr.KindOf(err) != axerr.InvalidConfig || len(axerr.IssuesOf(err)) == 0 {
		t.Errorf("invalid value: %v", err)
	}
	_, err = s.Set([]config.Op{config.SetValue(config.Keys("Battery", "nope"), 1.0)}, SetOptions{})
	if axerr.KindOf(err) != axerr.InvalidConfig {
		t.Errorf("unknown key: %v", err)
	}
	_, err = s.Set([]config.Op{config.SetValue(config.Keys("Idle", "enabled"), true)}, SetOptions{})
	if axerr.KindOf(err) != axerr.TakeoverRefused {
		t.Errorf("takeover without opt-in: %v", err)
	}
	if _, err := s.Set([]config.Op{config.SetValue(config.Keys("Idle", "enabled"), true)}, SetOptions{Takeover: true}); err != nil {
		t.Errorf("takeover with opt-in: %v", err)
	}
	mu.Lock()
	defer mu.Unlock()
	if len(events) != 2 || events[0].Config == nil || events[1].State.Revision != 3 {
		t.Errorf("events %+v", events)
	}
}

func TestReplaceKeepsTakeovers(t *testing.T) {
	t.Parallel()
	s := open(t, t.TempDir())
	current, _ := s.Config()
	next := jsonx.Clone(current).(*jsonx.Object)
	next.Value("Idle").(*jsonx.Object).Set("enabled", true)
	next.Value("Battery").(*jsonx.Object).Set("lowThreshold", 12.0)
	if _, err := s.Replace(next, SetOptions{}); err != nil {
		t.Fatal(err)
	}
	cfg, _ := s.Config()
	if cfg.Value("Idle").(*jsonx.Object).Value("enabled") != false || cfg.Value("Battery").(*jsonx.Object).Value("lowThreshold") != 12.0 {
		t.Error("a replace changed a takeover, or dropped the rest")
	}
}

func TestBrokenFileBlocksSavesUntilFixed(t *testing.T) {
	t.Parallel()
	dir := t.TempDir()
	s := open(t, dir)
	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()
	go s.Watch(ctx)
	time.Sleep(50 * time.Millisecond)

	path := filepath.Join(dir, FileName)
	os.WriteFile(path, []byte(`{"version": 75, "Battery": {"lowThreshold": "x"}`), 0o600)
	waitFor(t, func() bool { _, st := s.Config(); return st.Blocked })
	if _, err := s.Set([]config.Op{config.SetValue(config.Keys("Battery", "notify"), false)}, SetOptions{}); axerr.KindOf(err) != axerr.Conflict {
		t.Errorf("saved over a broken file: %v", err)
	}
	if data, _ := os.ReadFile(path); !strings.Contains(string(data), `"x"`) {
		t.Error("the broken file was overwritten")
	}
	os.WriteFile(path, []byte(`{"version": 75, "Battery": {"lowThreshold": 9}}`), 0o600)
	waitFor(t, func() bool {
		cfg, st := s.Config()
		return !st.Blocked && cfg.Value("Battery").(*jsonx.Object).Value("lowThreshold") == 9.0
	})
}

func TestOwnWritesDontReload(t *testing.T) {
	t.Parallel()
	dir := t.TempDir()
	s := open(t, dir)
	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()
	go s.Watch(ctx)
	time.Sleep(50 * time.Millisecond)
	n := 0
	s.Subscribe(func(Event) { n++ })
	s.Set([]config.Op{config.SetValue(config.Keys("Battery", "lowThreshold"), 16.0)}, SetOptions{})
	time.Sleep(150 * time.Millisecond)
	if n != 1 {
		t.Errorf("%d events for one write", n)
	}
}

func TestDeletedFileIsNotRecreated(t *testing.T) {
	t.Parallel()
	dir := t.TempDir()
	s := open(t, dir)
	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()
	go s.Watch(ctx)
	time.Sleep(50 * time.Millisecond)
	os.Remove(filepath.Join(dir, FileName))
	waitFor(t, func() bool { _, st := s.Config(); return st.Missing })
	if _, err := os.Stat(filepath.Join(dir, FileName)); err == nil {
		t.Error("recreated")
	}
}

func TestSymlinkedConfigStaysALink(t *testing.T) {
	t.Parallel()
	dir := t.TempDir()
	dots := t.TempDir()
	os.WriteFile(filepath.Join(dots, "config.json"), []byte(`{"version": 75}`), 0o644)
	os.Symlink(filepath.Join(dots, "config.json"), filepath.Join(dir, FileName))
	s := open(t, dir)
	if _, err := s.Set([]config.Op{config.SetValue(config.Keys("Battery", "lowThreshold"), 11.0)}, SetOptions{}); err != nil {
		t.Fatal(err)
	}
	if info, _ := os.Lstat(filepath.Join(dir, FileName)); info.Mode()&os.ModeSymlink == 0 {
		t.Error("the link was replaced")
	}
	if data, _ := os.ReadFile(filepath.Join(dots, "config.json")); !strings.Contains(string(data), `"lowThreshold": 11`) {
		t.Error("the target wasn't written")
	}
}

func waitFor(t *testing.T, cond func() bool) {
	t.Helper()
	for i := 0; i < 100; i++ {
		if cond() {
			return
		}
		time.Sleep(20 * time.Millisecond)
	}
	t.Fatal("timed out")
}
