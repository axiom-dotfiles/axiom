package config

import (
	"testing"
)

func TestParsePath(t *testing.T) {
	t.Parallel()
	cases := map[string]string{
		"Bars[main].location": "Bars.{id:main}.location",
		"A.b.c":               "A.b.c",
		"L[x][y]":             "L.{id:x}.{id:y}",
		"":                    "",
	}
	for in, want := range cases {
		p, err := ParsePath(in)
		if err != nil || p.String() != want {
			t.Errorf("ParsePath(%q) = %v, %v; want %s", in, p, err, want)
		}
	}
	for _, bad := range []string{"A..b", "L[]", "L[x", "L[x]y"} {
		if _, err := ParsePath(bad); err == nil {
			t.Errorf("ParsePath(%q) accepted", bad)
		}
	}
}

func TestResolveReadsKeysAfterListsAsIds(t *testing.T) {
	t.Parallel()
	c := cfg(t, `{"Bars":[{"id":"top","location":"Top"}]}`)
	p, _ := ParsePath("Bars.top.location")
	if got := Resolve(c, p).String(); got != "Bars.{id:top}.location" {
		t.Errorf("got %s", got)
	}
	if v, ok := Lookup(c, Resolve(c, p)); !ok || v != "Top" {
		t.Errorf("lookup %v %v", v, ok)
	}
}
