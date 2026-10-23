package rpc

import (
	"context"
	"encoding/json"
	"net"
	"path/filepath"
	"strings"
	"sync"
	"testing"
	"time"

	"github.com/axiom-shell/axiom/backend/internal/axerr"
)

type echoParams struct {
	Text string `json:"text"`
}

// serve starts a server on a socket in a temp dir and returns its path.
func serve(t *testing.T, reg *Registry, configure func(*Server)) (*Server, string) {
	t.Helper()
	path := filepath.Join(t.TempDir(), "s.sock")
	ln, err := Listen(path)
	if err != nil {
		t.Fatal(err)
	}
	s := &Server{Registry: reg}
	if configure != nil {
		configure(s)
	}
	ctx, cancel := context.WithCancel(context.Background())
	t.Cleanup(cancel)
	go s.Serve(ctx, ln)
	return s, path
}

func dial(t *testing.T, path string, reg *Registry) *Conn {
	t.Helper()
	c, err := Dial(context.Background(), path, reg, nil)
	if err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() { c.Close() })
	return c
}

func TestCallAndErrorKinds(t *testing.T) {
	t.Parallel()
	reg := NewRegistry()
	Handle(reg, "echo", func(ctx context.Context, c *Conn, p echoParams) (echoParams, error) { return p, nil })
	Handle(reg, "fail", func(ctx context.Context, c *Conn, p struct{}) (any, error) {
		return nil, &axerr.Error{Kind: axerr.InvalidConfig, Message: "bad", Issues: []axerr.Issue{{Path: "a", Message: "b"}}}
	})
	_, path := serve(t, reg, nil)
	c := dial(t, path, nil)
	var out echoParams
	if err := c.Call(context.Background(), "echo", echoParams{Text: "hi"}, &out); err != nil || out.Text != "hi" {
		t.Fatalf("echo: %v %+v", err, out)
	}
	err := c.Call(context.Background(), "fail", nil, nil)
	if axerr.KindOf(err) != axerr.InvalidConfig || len(axerr.IssuesOf(err)) != 1 {
		t.Errorf("fail: %v", err)
	}
	if err := c.Call(context.Background(), "nope", nil, nil); axerr.KindOf(err) != axerr.NotFound {
		t.Errorf("unknown method: %v", err)
	}
}

// A notification sent while handling a request arrives before its reply.
func TestPushBeforeReply(t *testing.T) {
	t.Parallel()
	reg := NewRegistry()
	Handle(reg, "set", func(ctx context.Context, c *Conn, p struct{}) (string, error) {
		c.Notify("changed", map[string]int{"revision": 2})
		return "ok", nil
	})
	_, path := serve(t, reg, nil)
	var mu sync.Mutex
	var order []string
	client := NewRegistry()
	Handle(client, "changed", func(ctx context.Context, c *Conn, p struct{ Revision int }) (any, error) {
		mu.Lock()
		order = append(order, "changed")
		mu.Unlock()
		return nil, nil
	})
	c := dial(t, path, client)
	for i := 0; i < 50; i++ {
		var out string
		if err := c.Call(context.Background(), "set", nil, &out); err != nil {
			t.Fatal(err)
		}
		mu.Lock()
		order = append(order, "reply")
		mu.Unlock()
	}
	// Handlers run concurrently, so check the count, then that no reply
	// came before its push: every prefix has at least as many pushes
	time.Sleep(50 * time.Millisecond)
	mu.Lock()
	defer mu.Unlock()
	pushes, replies := 0, 0
	for _, o := range order {
		if o == "changed" {
			pushes++
		} else {
			replies++
		}
		if replies > pushes {
			t.Fatalf("a reply overtook its push: %v", order)
		}
	}
}

func TestServerCallsClient(t *testing.T) {
	t.Parallel()
	got := make(chan *Conn, 1)
	_, path := serve(t, NewRegistry(), func(s *Server) { s.OnConnect = func(c *Conn) { got <- c } })
	client := NewRegistry()
	Handle(client, "ipc.call", func(ctx context.Context, c *Conn, p struct{ Target string }) (string, error) {
		return "called " + p.Target, nil
	})
	dial(t, path, client)
	sc := <-got
	var out string
	if err := sc.Call(context.Background(), "ipc.call", map[string]string{"target": "launcher"}, &out); err != nil || out != "called launcher" {
		t.Fatalf("%v %q", err, out)
	}
}

func TestPeerCheckRefuses(t *testing.T) {
	t.Parallel()
	_, path := serve(t, NewRegistry(), func(s *Server) {
		s.CheckPeer = func(net.Conn) error { return axerr.New(axerr.Refused, "no") }
	})
	c := dial(t, path, nil)
	if err := c.Call(context.Background(), "x", nil, nil); axerr.KindOf(err) != axerr.Unavailable {
		t.Errorf("refused peer got an answer: %v", err)
	}
}

func TestRealPeerIsThisUser(t *testing.T) {
	t.Parallel()
	got := make(chan error, 1)
	_, path := serve(t, NewRegistry(), func(s *Server) {
		s.CheckPeer = func(nc net.Conn) error { err := SamePeerUser(nc); got <- err; return err }
	})
	dial(t, path, nil)
	if err := <-got; err != nil {
		t.Errorf("own user refused: %v", err)
	}
}

func TestLimits(t *testing.T) {
	t.Parallel()
	reg := NewRegistry()
	Handle(reg, "echo", func(ctx context.Context, c *Conn, p json.RawMessage) (json.RawMessage, error) { return p, nil })
	_, path := serve(t, reg, func(s *Server) { s.Limits = Limits{MaxLine: 1 << 10, MaxDepth: 8, MaxInFlight: 4, QueueSize: 64} })
	c := dial(t, path, nil)
	// Refused before its id is read, so it's answered with id null: the
	// call itself only times out
	deep := json.RawMessage(strings.Repeat("[", 20) + strings.Repeat("]", 20))
	dctx, dcancel := context.WithTimeout(context.Background(), 200*time.Millisecond)
	defer dcancel()
	if err := c.Call(dctx, "echo", deep, nil); err == nil {
		t.Error("a message nested past the limit was answered")
	}
	ctx, cancel := context.WithTimeout(context.Background(), 200*time.Millisecond)
	defer cancel()
	big := json.RawMessage(`"` + strings.Repeat("a", 4<<10) + `"`)
	if err := c.Call(ctx, "echo", big, nil); err == nil {
		t.Error("an oversized message was answered")
	}
	select {
	case <-c.Done():
	case <-time.After(time.Second):
		t.Error("the connection survived an oversized message")
	}
}

func TestDialRefusesNonSocket(t *testing.T) {
	t.Parallel()
	path := filepath.Join(t.TempDir(), "x")
	if _, err := Dial(context.Background(), path, nil, nil); axerr.KindOf(err) != axerr.Unavailable {
		t.Errorf("missing: %v", err)
	}
}

func TestDepth(t *testing.T) {
	t.Parallel()
	if d := depth([]byte(`{"a":["[[[",{"b":[]}]}`)); d != 4 {
		t.Errorf("depth %d", d)
	}
}
