package wire

import (
	"bytes"
	"encoding/binary"
	"net"
	"path/filepath"
	"testing"
	"time"
)

func wireString(s string) []byte {
	n := len(s) + 1
	b := make([]byte, 4+(n+3)&^3)
	binary.LittleEndian.PutUint32(b, uint32(n))
	copy(b[4:], s)
	return b
}

// A scripted compositor: answers get_registry and sync with two globals
// and the callback's done.
func TestGlobalsAgainstAFakeCompositor(t *testing.T) {
	t.Parallel()
	sock := filepath.Join(t.TempDir(), "w")
	ln, err := net.Listen("unix", sock)
	if err != nil {
		t.Fatal(err)
	}
	defer ln.Close()
	go func() {
		c, err := ln.Accept()
		if err != nil {
			return
		}
		defer c.Close()
		for i := 0; i < 2; i++ { // get_registry, sync
			if _, _, _, err := readMessage(c); err != nil {
				return
			}
		}
		var out bytes.Buffer
		writeMessage(&out, 2, evGlobal, uint32Arg(1), wireString("wl_compositor"), uint32Arg(6))
		writeMessage(&out, 2, evGlobal, uint32Arg(7), wireString("ext_idle_notifier_v1"), uint32Arg(2))
		writeMessage(&out, 3, evCallbackDone, uint32Arg(0))
		c.Write(out.Bytes())
	}()
	globals, err := Globals(sock, time.Second)
	if err != nil {
		t.Fatal(err)
	}
	if len(globals) != 2 || globals[0].Interface != "ext_idle_notifier_v1" || globals[0].Version != 2 || globals[1].Name != 1 {
		t.Errorf("globals %+v", globals)
	}
}

func TestStrings(t *testing.T) {
	t.Parallel()
	for _, s := range []string{"", "a", "abc", "abcd", "wl_seat"} {
		b := append(wireString(s), 9, 0, 0, 0)
		got, rest := readStringRest(b)
		if s != "" && (got != s || readUint(rest) != 9) {
			t.Errorf("%q: got %q rest %v", s, got, rest)
		}
	}
}
