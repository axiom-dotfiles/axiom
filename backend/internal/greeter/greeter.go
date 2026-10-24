// Package greeter loads the config axiom's login screen runs on. The
// greeter runs as greetd's user, from a root-owned copy of axiom, so it
// never reads the user's config.json: the user's axiom exports the part
// the greeter shows (the bundle, GreeterBundle.qml: a partial format-2
// config, and format 1 from before) to the greeter's folder, and the
// install keeps a snapshot of it (fallback/) for when the bundle doesn't
// load. Only data crosses: this pipeline, the greeter's own, turns it
// into a config.
package greeter

import (
	"errors"
	"io/fs"
	"os"

	"github.com/axiom-shell/axiom/backend/internal/config"
	"github.com/axiom-shell/axiom/backend/internal/jsonx"
	"github.com/axiom-shell/axiom/backend/internal/migrate/convert"
	"github.com/axiom-shell/axiom/backend/internal/migrate/steps"
)

// Candidate is a file the config may come from: Source names it
// ("bundle", "fallback").
type Candidate struct {
	Source string
	Path   string
}

// Problem is why a candidate was passed over.
type Problem struct {
	Source string `json:"source"`
	Error  string `json:"error"`
}

// Result is the config the greeter runs on and where it came from: a
// candidate's Source, or "defaults" when none loaded.
type Result struct {
	Source   string
	Config   *jsonx.Object
	Problems []Problem
}

// Load is the first candidate that loads through p (converted, pruned,
// filled and valid), else p's defaults. A format-2 file newer than this
// axiom (the user's updated before the greeter's copy) is still tried, as
// the current version: its unknown keys are pruned, and only what breaks
// validation passes it over.
func Load(p config.Pipeline, candidates []Candidate) Result {
	var problems []Problem
	for _, c := range candidates {
		cfg, err := load(p, c.Path)
		if err != nil {
			problems = append(problems, Problem{Source: c.Source, Error: err.Error()})
			continue
		}
		return Result{Source: c.Source, Config: cfg, Problems: problems}
	}
	return Result{Source: "defaults", Config: p.Defaults(), Problems: problems}
}

func load(p config.Pipeline, path string) (*jsonx.Object, error) {
	data, err := os.ReadFile(path)
	if errors.Is(err, fs.ErrNotExist) {
		return nil, errors.New("missing")
	}
	if err != nil {
		return nil, err
	}
	parsed, err := jsonx.Unmarshal(data)
	if err != nil {
		return nil, errors.New("not JSON: " + err.Error())
	}
	if obj, ok := parsed.(*jsonx.Object); ok {
		if version, _ := obj.Value("version").(float64); obj.Value("format") == float64(convert.Format) && version > float64(steps.Current()) {
			obj.Set("version", float64(steps.Current()))
		}
	}
	loaded, err := p.Load(parsed)
	if err != nil {
		return nil, err
	}
	if len(loaded.Errors) > 0 {
		msg := loaded.Errors[0]
		if len(loaded.Errors) > 1 {
			msg += " (and more)"
		}
		return nil, errors.New(msg)
	}
	return loaded.Config, nil
}
