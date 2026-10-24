package daemon

import (
	"context"
	"sync"
	"time"

	"github.com/axiom-shell/axiom/backend/internal/rpc"
	"github.com/axiom-shell/axiom/backend/internal/store"
)

// A part is one piece of the daemon: the RPC methods it answers, what it
// runs while the daemon runs, and what it does when the config changes.
// Run starts every part's run on the daemon's tasks and waits for them, so
// a new piece (as the compositor's was) is one more part, never more wiring.
type part struct {
	name string
	// methods registers its RPC methods
	methods func(*rpc.Registry)
	// run runs until ctx ends; an error stops the daemon
	run func(ctx context.Context) error
	// onConfig is told of every config change, in order. It runs on the
	// store's delivery: it may read the store and write to it, but
	// anything slow goes to a kicker.
	onConfig func(store.Event)
}

// tasks owns the daemon's goroutines: each gets the daemon's context, and
// Run waits for all of them before it returns.
type tasks struct {
	ctx context.Context
	wg  sync.WaitGroup
}

// Go runs fn on a goroutine of its own, until it returns or ctx ends.
func (t *tasks) Go(fn func(ctx context.Context)) {
	t.wg.Add(1)
	go func() {
		defer t.wg.Done()
		fn(t.ctx)
	}()
}

// Wait waits for every goroutine started.
func (t *tasks) Wait() { t.wg.Wait() }

// kicker runs fn on one goroutine whenever kicked: kicks while it runs
// fold into one more run, so it never overlaps itself and never falls
// behind.
type kicker struct {
	ch chan struct{}
	fn func(ctx context.Context)
}

func newKicker(fn func(ctx context.Context)) *kicker {
	return &kicker{ch: make(chan struct{}, 1), fn: fn}
}

// Kick asks for a run without waiting for it.
func (k *kicker) Kick() { notify(k.ch) }

// run runs fn for each kick until ctx ends.
func (k *kicker) run(ctx context.Context) error {
	for {
		select {
		case <-ctx.Done():
			return nil
		case <-k.ch:
			k.fn(ctx)
		}
	}
}

// debouncer calls fn once events have stopped coming for delay: a burst
// of writes (an editor's save, a build) is one call.
type debouncer struct {
	delay time.Duration
	timer *time.Timer
	fire  chan struct{}
}

func newDebouncer(delay time.Duration) *debouncer {
	return &debouncer{delay: delay, fire: make(chan struct{}, 1)}
}

// Event (re)starts the wait.
func (b *debouncer) Event() {
	if b.timer == nil {
		b.timer = time.AfterFunc(b.delay, func() { notify(b.fire) })
	} else {
		b.timer.Reset(b.delay)
	}
}

// C is signalled once the wait is over.
func (b *debouncer) C() <-chan struct{} { return b.fire }

// Stop drops a wait in progress.
func (b *debouncer) Stop() {
	if b.timer != nil {
		b.timer.Stop()
	}
}

// notify signals ch without blocking: one pending signal is enough, and a
// timer firing after its watcher returned must not hang.
func notify(ch chan struct{}) {
	select {
	case ch <- struct{}{}:
	default:
	}
}
