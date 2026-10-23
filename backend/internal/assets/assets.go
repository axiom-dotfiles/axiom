// Package assets holds the repo files compiled into the binary: the config
// schema, theme defaults and the protocol file. The copies under data/ are
// generated (tools/syncassets); edit the originals in the repo.
package assets

import (
	"embed"
	"io/fs"
)

//go:generate go run ../../tools/syncassets ../../.. data

//go:embed all:data
var data embed.FS

// FS is the embedded tree, rooted like the repo (config/json/…).
func FS() fs.FS {
	sub, err := fs.Sub(data, "data")
	if err != nil {
		panic(err) // the directive above guarantees data/ exists
	}
	return sub
}

// Read returns one embedded file by its repo path.
func Read(name string) ([]byte, error) {
	return fs.ReadFile(FS(), name)
}
