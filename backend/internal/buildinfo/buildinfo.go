// Package buildinfo says what this binary is: its version, the commit it
// was built from, and the protocol it speaks to the shell. The shell and
// the binary agree to talk only when the protocol (config/json/backend.json)
// and the schema hash match (daemon.hello), so a version string is only ever
// informational.
package buildinfo

import (
	"crypto/md5"
	"encoding/hex"
	"encoding/json"
	"fmt"
	"runtime"
	"runtime/debug"
	"sync"

	"github.com/axiom-shell/axiom/backend/internal/assets"
)

// version is stamped by release builds:
//
//	go build -ldflags "-X github.com/axiom-shell/axiom/backend/internal/buildinfo.version=v1.2.0"
//
// Dev builds leave it empty and report the VCS revision instead.
var version string

// Info describes the running binary.
type Info struct {
	Version    string `json:"version"`
	Commit     string `json:"commit"`
	Dirty      bool   `json:"dirty"`
	GoVersion  string `json:"goVersion"`
	Platform   string `json:"platform"`
	Protocol   int    `json:"protocol"`
	SchemaHash string `json:"schemaHash"`
}

var load = sync.OnceValue(func() Info {
	info := Info{
		Version:   version,
		GoVersion: runtime.Version(),
		Platform:  runtime.GOOS + "/" + runtime.GOARCH,
		Protocol:  mustProtocol(),
	}
	if bi, ok := debug.ReadBuildInfo(); ok {
		for _, s := range bi.Settings {
			switch s.Key {
			case "vcs.revision":
				info.Commit = s.Value
			case "vcs.modified":
				info.Dirty = s.Value == "true"
			}
		}
	}
	if info.Version == "" {
		info.Version = "dev"
	}
	if schema, err := assets.Read("config/json/config.schema.json"); err == nil {
		info.SchemaHash = SchemaHash(schema)
	}
	return info
})

// Get returns this binary's build info.
func Get() Info { return load() }

// Protocol is the protocol number this binary speaks.
func Protocol() int { return load().Protocol }

// SchemaHash is the identity of a schema text, compared in daemon.hello.
// md5 because it's what QML has (Qt.md5); it identifies, it doesn't protect.
func SchemaHash(schema []byte) string {
	sum := md5.Sum(schema)
	return hex.EncodeToString(sum[:])
}

func mustProtocol() int {
	raw, err := assets.Read("config/json/backend.json")
	if err != nil {
		panic(fmt.Sprintf("buildinfo: embedded backend.json: %v", err))
	}
	var file struct {
		Protocol int `json:"protocol"`
	}
	if err := json.Unmarshal(raw, &file); err != nil || file.Protocol < 1 {
		panic(fmt.Sprintf("buildinfo: embedded backend.json has no protocol (%v)", err))
	}
	return file.Protocol
}
