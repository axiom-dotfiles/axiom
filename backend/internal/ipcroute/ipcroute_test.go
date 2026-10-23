package ipcroute

import (
	"reflect"
	"testing"
)

func TestParseShow(t *testing.T) {
	t.Parallel()
	got := ParseShow("target brightness\n  function set(percent: int): void\n  function up(): void\ntarget todo\n  function add(text: string): bool\n")
	want := map[string][]Function{
		"brightness": {{Name: "set", Args: []Arg{{"percent", "int"}}, Returns: "void"}, {Name: "up", Returns: "void"}},
		"todo":       {{Name: "add", Args: []Arg{{"text", "string"}}, Returns: "bool"}},
	}
	if !reflect.DeepEqual(got, want) {
		t.Errorf("got %+v", got)
	}
}

func TestCoerce(t *testing.T) {
	t.Parallel()
	fn := Function{Name: "f", Args: []Arg{{"n", "int"}, {"on", "bool"}, {"s", "string"}}}
	args, err := coerce(fn, []string{"5", "true", "x"})
	if err != nil || !reflect.DeepEqual(args, []any{5, true, "x"}) {
		t.Errorf("%v %v", args, err)
	}
	if _, err := coerce(fn, []string{"five", "true", "x"}); err == nil {
		t.Error("a word passed as an int")
	}
	if _, err := coerce(fn, []string{"5"}); err == nil {
		t.Error("too few arguments passed")
	}
}
