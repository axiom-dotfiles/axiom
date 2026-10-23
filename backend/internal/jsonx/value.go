// Package jsonx is axiom's JSON tree: the config is held, migrated and
// written as one of these rather than as Go structs, so key order, unknown
// keys and old shapes survive, and the bytes written are exactly the ones
// the shell's JS (V4) would write. Pure: no I/O.
//
// A value is one of nil (null), bool, float64, string, *Object or *Array.
// Objects and arrays are pointers, so code ported from the JS helpers can
// edit nested values in place as the JS does.
package jsonx

import (
	"sort"
	"strconv"
)

// Object is a JSON object that iterates in JS property order: keys that are
// array indices ("0", "1", … up to 2^32-2) first in ascending order, then
// every other key in insertion order. Setting an existing key keeps its
// place, as in JS.
type Object struct {
	order  []string
	values map[string]any
	// how many keys are array indices: while none are, order is the
	// iteration order as is
	indexKeys int
}

// NewObject returns an empty object.
func NewObject() *Object {
	return &Object{values: map[string]any{}}
}

// Obj builds an object from alternating keys and values, in order.
func Obj(kv ...any) *Object {
	if len(kv)%2 != 0 {
		panic("jsonx.Obj: odd number of arguments")
	}
	o := NewObject()
	for i := 0; i < len(kv); i += 2 {
		o.Set(kv[i].(string), kv[i+1])
	}
	return o
}

// Len is the number of keys.
func (o *Object) Len() int { return len(o.order) }

// Get returns the value at key and whether the key is there.
func (o *Object) Get(key string) (any, bool) {
	v, ok := o.values[key]
	return v, ok
}

// Value returns the value at key, nil when missing.
func (o *Object) Value(key string) any { return o.values[key] }

// Has reports whether key is there.
func (o *Object) Has(key string) bool {
	_, ok := o.values[key]
	return ok
}

// Set sets key to v, appending the key when it's new.
func (o *Object) Set(key string, v any) {
	if _, ok := o.values[key]; !ok {
		o.order = append(o.order, key)
		if IsArrayIndex(key) {
			o.indexKeys++
		}
	}
	o.values[key] = v
}

// Delete removes key, reporting whether it was there.
func (o *Object) Delete(key string) bool {
	if _, ok := o.values[key]; !ok {
		return false
	}
	delete(o.values, key)
	for i, k := range o.order {
		if k == key {
			o.order = append(o.order[:i:i], o.order[i+1:]...)
			break
		}
	}
	if IsArrayIndex(key) {
		o.indexKeys--
	}
	return true
}

// Keys returns the keys in JS iteration order. The slice is the caller's.
func (o *Object) Keys() []string {
	keys := make([]string, len(o.order))
	copy(keys, o.order)
	if o.indexKeys == 0 {
		return keys
	}
	// Array indices first, ascending; the rest keep insertion order
	sort.SliceStable(keys, func(i, j int) bool {
		ai, bi := IsArrayIndex(keys[i]), IsArrayIndex(keys[j])
		if ai && bi {
			x, _ := strconv.ParseUint(keys[i], 10, 32)
			y, _ := strconv.ParseUint(keys[j], 10, 32)
			return x < y
		}
		return ai && !bi
	})
	return keys
}

// IsArrayIndex reports whether key is a canonical array index, the keys JS
// orders first: "0" or a number without leading zeros below 2^32-1.
func IsArrayIndex(key string) bool {
	if key == "" || len(key) > 10 || (key[0] == '0' && len(key) > 1) {
		return false
	}
	for i := 0; i < len(key); i++ {
		if key[i] < '0' || key[i] > '9' {
			return false
		}
	}
	n, err := strconv.ParseUint(key, 10, 64)
	return err == nil && n < 1<<32-1
}

// Array is a JSON array.
type Array struct {
	Items []any
}

// Arr builds an array of items.
func Arr(items ...any) *Array {
	if items == nil {
		items = []any{}
	}
	return &Array{Items: items}
}

// Len is the number of items.
func (a *Array) Len() int { return len(a.Items) }

// Append adds items at the end.
func (a *Array) Append(items ...any) { a.Items = append(a.Items, items...) }

// Clone returns a deep copy of v.
func Clone(v any) any {
	switch t := v.(type) {
	case *Object:
		c := &Object{order: make([]string, len(t.order)), values: make(map[string]any, len(t.values)), indexKeys: t.indexKeys}
		copy(c.order, t.order)
		for k, x := range t.values {
			c.values[k] = Clone(x)
		}
		return c
	case *Array:
		c := &Array{Items: make([]any, len(t.Items))}
		for i, x := range t.Items {
			c.Items[i] = Clone(x)
		}
		return c
	default:
		return v
	}
}

// Equal reports whether a and b are the same JSON value, objects compared
// by their keys regardless of order (Utils.deepEqual).
func Equal(a, b any) bool {
	switch x := a.(type) {
	case *Object:
		y, ok := b.(*Object)
		if !ok || x.Len() != y.Len() {
			return false
		}
		for k, xv := range x.values {
			yv, ok := y.values[k]
			if !ok || !Equal(xv, yv) {
				return false
			}
		}
		return true
	case *Array:
		y, ok := b.(*Array)
		if !ok || len(x.Items) != len(y.Items) {
			return false
		}
		for i := range x.Items {
			if !Equal(x.Items[i], y.Items[i]) {
				return false
			}
		}
		return true
	case float64:
		y, ok := b.(float64)
		return ok && x == y
	default:
		return a == b
	}
}

// TypeOf is JS's typeof for a value: "object" for null, objects and arrays.
func TypeOf(v any) string {
	switch v.(type) {
	case bool:
		return "boolean"
	case float64:
		return "number"
	case string:
		return "string"
	default:
		return "object"
	}
}

// AsObject returns v as an object (a JS plain object), if it is one.
func AsObject(v any) (*Object, bool) {
	o, ok := v.(*Object)
	return o, ok
}

// AsArray returns v as an array, if it is one.
func AsArray(v any) (*Array, bool) {
	a, ok := v.(*Array)
	return a, ok
}
