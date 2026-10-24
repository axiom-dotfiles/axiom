package luacheck

import (
	"context"
	"errors"
	"os/exec"
	"testing"
)

func TestParses(t *testing.T) {
	t.Parallel()
	standIn := Checker{LookPath: func(string) (string, error) { return "", errors.New("none") }}
	cases := []struct {
		name, src    string
		luac, gopher bool
	}{
		{"a chunk", "local x = 1\nhl.bind(\"SUPER + Q\", function() end)\n", true, true},
		{"an unclosed function", "hl.on(\"x\", function()\n", false, false},
		// Lua 5.4 only: luac (Hyprland's Lua) takes it, the stand-in doesn't
		{"integer division", "local x = 7 // 2\n", true, false},
	}
	_, err := exec.LookPath("luac")
	hasLuac := err == nil
	for _, c := range cases {
		t.Run(c.name, func(t *testing.T) {
			t.Parallel()
			if got := standIn.Parses(context.Background(), c.src); got != c.gopher {
				t.Errorf("stand-in: got %v, want %v", got, c.gopher)
			}
			if hasLuac {
				if got := (Checker{}).Parses(context.Background(), c.src); got != c.luac {
					t.Errorf("luac: got %v, want %v", got, c.luac)
				}
			}
		})
	}
}
