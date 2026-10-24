package config

import (
	"strings"

	"github.com/axiom-shell/axiom/backend/internal/axerr"
	"github.com/axiom-shell/axiom/backend/internal/jsonx"
	"github.com/axiom-shell/axiom/backend/internal/schema"
)

// ParsePath reads the command line's form of a path: keys joined by ".",
// a list item by its id in brackets: `Bars[main].location`.
func ParsePath(text string) (Path, error) {
	if strings.TrimSpace(text) == "" {
		return nil, nil
	}
	var p Path
	for _, part := range strings.Split(text, ".") {
		key, rest, _ := strings.Cut(part, "[")
		if key != "" {
			p = append(p, Segment{Key: key})
		}
		for rest != "" {
			id, after, ok := strings.Cut(rest, "]")
			if !ok || id == "" {
				return nil, axerr.New(axerr.BadRequest, "bad path %q: an item is [its id]", text)
			}
			p = append(p, Segment{ID: id})
			rest = strings.TrimPrefix(after, "[")
			if after != "" && !strings.HasPrefix(after, "[") {
				return nil, axerr.New(axerr.BadRequest, "bad path %q", text)
			}
		}
		if key == "" && !strings.HasPrefix(part, "[") {
			return nil, axerr.New(axerr.BadRequest, "bad path %q: an empty key", text)
		}
	}
	return p, nil
}

// Resolve reads a key that follows a list as an item's id, so a dotted
// path needs no brackets (`Bars.main.location`): the config knows which
// nodes are lists.
func Resolve(cfg *jsonx.Object, path Path) Path {
	out := make(Path, 0, len(path))
	var node any = cfg
	for _, seg := range path {
		if _, isList := node.(*jsonx.Array); isList && seg.ID == "" {
			seg = Segment{ID: seg.Key}
		}
		out = append(out, seg)
		node, _ = get(node, seg)
	}
	return out
}

// Lookup is the value at path in cfg.
func Lookup(cfg *jsonx.Object, path Path) (any, bool) {
	var node any = cfg
	for _, seg := range path {
		next, ok := get(node, seg)
		if !ok {
			return nil, false
		}
		node = next
	}
	return node, true
}

// NodeAt is the schema node a path leads to, following properties, list
// items (the oneOf option of the item there in cfg) and object maps.
func NodeAt(s *schema.Schema, cfg *jsonx.Object, path Path) (any, bool) {
	node := s.Root()
	var value any = cfg
	for _, seg := range path {
		node = s.Resolve(node)
		if jsonx.Truthy(schema.Get(node, "oneOf")) {
			node = s.Discriminate(value, node)
		}
		var next any
		if seg.ID != "" {
			next = schema.Get(node, "items")
		} else if p := schema.Get(schema.Get(node, "properties"), seg.Key); p != nil {
			next = p
		} else if ap, ok := schema.Get(node, "additionalProperties").(*jsonx.Object); ok {
			next = ap
		}
		if next == nil {
			return nil, false
		}
		node = next
		value, _ = get(value, seg)
	}
	node = s.Resolve(node)
	if jsonx.Truthy(schema.Get(node, "oneOf")) {
		if d := s.Discriminate(value, node); d != nil {
			node = d
		}
	}
	return node, true
}

// ParseValue reads a command-line value as the schema node's type wants:
// booleans as true/false/on/off/yes/no, numbers as numbers, strings as
// they are, anything else as JSON.
func ParseValue(node any, text string) (any, error) {
	switch schema.Get(node, "type") {
	case "string":
		return text, nil
	case "boolean":
		switch strings.ToLower(strings.TrimSpace(text)) {
		case "true", "on", "yes", "1":
			return true, nil
		case "false", "off", "no", "0":
			return false, nil
		}
		return nil, axerr.New(axerr.BadRequest, "%q isn't on or off", text)
	case "integer", "number":
		v, err := jsonx.Unmarshal([]byte(strings.TrimSpace(text)))
		f, ok := v.(float64)
		if err != nil || !ok {
			return nil, axerr.New(axerr.BadRequest, "%q isn't a number", text)
		}
		if schema.Get(node, "type") == "integer" && !jsonx.IsInteger(f) {
			return nil, axerr.New(axerr.BadRequest, "%q isn't a whole number", text)
		}
		return f, nil
	}
	v, err := jsonx.Unmarshal([]byte(text))
	if err != nil {
		return nil, axerr.New(axerr.BadRequest, "give this value as JSON (%v)", err)
	}
	return v, nil
}
