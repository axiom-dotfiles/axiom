package share

import (
	"testing"

	"github.com/axiom-shell/axiom/backend/internal/jsonx"
	"github.com/axiom-shell/axiom/backend/internal/schema"
	"github.com/axiom-shell/axiom/backend/internal/testkit"
)

// The share.* cases recorded from ConfigExamples.qml, replayed here: each
// output must be the JS bytes exactly.
func TestSharedShareCases(t *testing.T) {
	t.Parallel()
	for _, c := range testkit.Cases(t, "share.") {
		// keepMovedKeys works on format 2's paths here (a format-1 file is
		// converted before it's applied); the recorded cases hold format
		// 1's: TestKeepMovedKeysV2 has its own
		if c.Op == "share.keepMovedKeys" {
			continue
		}
		t.Run(c.Name, func(t *testing.T) {
			t.Parallel()
			c.Compare(t, run(t, c))
		})
	}
}

func run(t *testing.T, c testkit.Case) any {
	a := c.Args
	sch := func(i int) *schema.Schema { return schema.New(a[i]) }
	switch c.Op {
	case "share.pick":
		return Pick(sch(1), a[0], strs(a[2]), monitors(a[3]))
	case "share.apply":
		return Apply(sch(2), a[0], a[1], strs(a[3]), monitors(a[4]))
	case "share.sparse":
		return Sparse(sch(1), a[0])
	case "share.snapshot":
		return Snapshot(sch(1), a[0])
	case "share.snapshotFiles":
		return array(SnapshotFiles(sch(1), a[0]))
	case "share.snapshotPaths":
		return paths(SnapshotPaths(sch(0)))
	case "share.takeoverPaths":
		return paths(TakeoverPaths(sch(0)))
	case "share.keepTakeovers":
		var ps [][]string
		for _, p := range a[2].(*jsonx.Array).Items {
			ps = append(ps, strs(p))
		}
		return KeepTakeovers(a[0], a[1], ps)
	case "share.withSnapshot":
		return WithSnapshot(sch(2), a[0], a[1], strs(a[3]))
	case "share.monitorOrder":
		return MonitorOrder(a[0])
	}
	t.Fatalf("unknown op %s", c.Op)
	return nil
}

func strs(v any) []string {
	arr, _ := v.(*jsonx.Array)
	out := []string{}
	if arr != nil {
		for _, x := range arr.Items {
			s, _ := x.(string)
			out = append(out, s)
		}
	}
	return out
}

func monitors(v any) Monitors {
	if v == nil {
		return nil
	}
	return Monitors(strs(v))
}

func array(list []string) *jsonx.Array {
	a := jsonx.Arr()
	for _, s := range list {
		a.Append(s)
	}
	return a
}

func paths(list [][]string) *jsonx.Array {
	a := jsonx.Arr()
	for _, p := range list {
		a.Append(array(p))
	}
	return a
}
