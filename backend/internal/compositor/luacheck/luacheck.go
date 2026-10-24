// Package luacheck says whether Lua source parses, for edits axiom makes to
// a user's Hyprland files: an edit that would leave a file unparsable is
// never written. Hyprland embeds Lua 5.4, and gopher-lua parses 5.1, so
// `luac` decides where it's installed and gopher-lua only stands in for it.
package luacheck

import (
	"context"
	"errors"
	"os/exec"
	"strings"
	"time"

	"github.com/yuin/gopher-lua/parse"
)

// Checker answers Parses; the zero value looks `luac` up on $PATH.
type Checker struct {
	// LookPath finds luac (default exec.LookPath); tests force the stand-in
	// by returning an error
	LookPath func(string) (string, error)
}

// Parses reports whether src is a Lua chunk that parses.
func (c Checker) Parses(ctx context.Context, src string) bool {
	return c.Check(ctx, src) == nil
}

// Check is why src doesn't parse (luac's message), or nil.
func (c Checker) Check(ctx context.Context, src string) error {
	look := c.LookPath
	if look == nil {
		look = exec.LookPath
	}
	if luac, err := look("luac"); err == nil {
		ctx, cancel := context.WithTimeout(ctx, 10*time.Second)
		defer cancel()
		cmd := exec.CommandContext(ctx, luac, "-p", "-")
		cmd.Stdin = strings.NewReader(src)
		var stderr strings.Builder
		cmd.Stderr = &stderr
		if err := cmd.Run(); err != nil {
			if msg := strings.TrimSpace(stderr.String()); msg != "" {
				return errors.New(msg)
			}
			return err
		}
		return nil
	}
	_, err := parse.Parse(strings.NewReader(src), "check")
	return err
}
