// Package legacy upgrades a format-1 config (versions 1 to 75, from before
// the axiom binary owned the config) to version 75 by running the shell's
// own frozen migration code (legacy.js) in an embedded JS engine. The code
// is frozen, so running it is exact where a port could drift; the shared
// fixtures (legacy and corpus suites) check it against the shell's engine.
// Pure: the engine has no I/O, timers or host access.
package legacy

import (
	_ "embed"
	"fmt"
	"sync"
	"time"

	"github.com/dop251/goja"

	"github.com/axiom-shell/axiom/backend/internal/jsonx"
)

//go:embed legacy.js
var source string

// LastVersion is the last format-1 version: legacy.js's currentVersion.
const LastVersion = 75

// Result is migrate()'s: the upgraded config, secrets pulled out of it,
// what was done (English, for the log), and whether anything was.
type Result struct {
	Config   *jsonx.Object
	Secrets  *jsonx.Object
	Changes  []string
	Migrated bool
}

// timeout bounds one run: migrating a config takes milliseconds, so this
// only stops a pathological input from hanging the caller
const timeout = 10 * time.Second

var program = sync.OnceValues(func() (*goja.Program, error) {
	return goja.Compile("legacy.js", source+"\n;(function (text) { return JSON.stringify(ConfigMigration.migrate(JSON.parse(text))); })", true)
})

// Migrate runs ConfigMigration.migrate on config (not modified). A config
// that isn't an object is treated as the JS does (`config ?? {}` then
// property reads).
func Migrate(config any) (Result, error) {
	prog, err := program()
	if err != nil {
		return Result{}, fmt.Errorf("legacy migrations don't compile: %w", err)
	}
	vm := goja.New()
	timer := time.AfterFunc(timeout, func() { vm.Interrupt("legacy migration timed out") })
	defer timer.Stop()

	fn, err := vm.RunProgram(prog)
	if err != nil {
		return Result{}, fmt.Errorf("legacy migrations: %w", err)
	}
	call, ok := goja.AssertFunction(fn)
	if !ok {
		return Result{}, fmt.Errorf("legacy migrations: no entry point")
	}
	out, err := call(goja.Undefined(), vm.ToValue(string(jsonx.MarshalCompact(config))))
	if err != nil {
		return Result{}, fmt.Errorf("migrating the config: %w", err)
	}
	parsed, err := jsonx.Unmarshal([]byte(out.String()))
	if err != nil {
		return Result{}, fmt.Errorf("legacy migrations returned bad JSON: %w", err)
	}
	obj, _ := parsed.(*jsonx.Object)
	res := Result{Migrated: obj.Value("migrated") == true}
	res.Config, _ = obj.Value("config").(*jsonx.Object)
	res.Secrets, _ = obj.Value("secrets").(*jsonx.Object)
	if res.Config == nil || res.Secrets == nil {
		return Result{}, fmt.Errorf("legacy migrations returned no config")
	}
	if changes, ok := obj.Value("changes").(*jsonx.Array); ok {
		for _, c := range changes.Items {
			res.Changes = append(res.Changes, jsonx.ToString(c))
		}
	}
	return res, nil
}

// Object is r as the JS returned it ({config, secrets, changes, migrated}).
func (r Result) Object() *jsonx.Object {
	changes := jsonx.Arr()
	for _, c := range r.Changes {
		changes.Append(c)
	}
	return jsonx.Obj("config", r.Config, "secrets", r.Secrets, "changes", changes, "migrated", r.Migrated)
}
