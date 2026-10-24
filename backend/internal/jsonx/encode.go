package jsonx

import (
	"bytes"
	"math"
	"unicode/utf8"
)

// Marshal is JSON.stringify(v, null, 2) followed by a newline: the bytes
// axiom writes every JSON file with, matching what V4 produces for the same
// value. Non-finite numbers are written as null, like JSON.stringify.
func Marshal(v any) []byte {
	var b bytes.Buffer
	encode(&b, v, 0)
	b.WriteByte('\n')
	return b.Bytes()
}

// MarshalCompact is JSON.stringify(v): no whitespace, no newline.
func MarshalCompact(v any) []byte {
	var b bytes.Buffer
	encodeCompact(&b, v)
	return b.Bytes()
}

func encode(b *bytes.Buffer, v any, depth int) {
	switch t := v.(type) {
	case *Object:
		keys := t.Keys()
		if len(keys) == 0 {
			b.WriteString("{}")
			return
		}
		b.WriteString("{\n")
		for i, k := range keys {
			indent(b, depth+1)
			writeString(b, k)
			b.WriteString(": ")
			encode(b, t.values[k], depth+1)
			if i < len(keys)-1 {
				b.WriteByte(',')
			}
			b.WriteByte('\n')
		}
		indent(b, depth)
		b.WriteByte('}')
	case *Array:
		if len(t.Items) == 0 {
			b.WriteString("[]")
			return
		}
		b.WriteString("[\n")
		for i, x := range t.Items {
			indent(b, depth+1)
			encode(b, x, depth+1)
			if i < len(t.Items)-1 {
				b.WriteByte(',')
			}
			b.WriteByte('\n')
		}
		indent(b, depth)
		b.WriteByte(']')
	default:
		encodeScalar(b, v)
	}
}

func encodeCompact(b *bytes.Buffer, v any) {
	switch t := v.(type) {
	case *Object:
		b.WriteByte('{')
		for i, k := range t.Keys() {
			if i > 0 {
				b.WriteByte(',')
			}
			writeString(b, k)
			b.WriteByte(':')
			encodeCompact(b, t.values[k])
		}
		b.WriteByte('}')
	case *Array:
		b.WriteByte('[')
		for i, x := range t.Items {
			if i > 0 {
				b.WriteByte(',')
			}
			encodeCompact(b, x)
		}
		b.WriteByte(']')
	default:
		encodeScalar(b, v)
	}
}

func encodeScalar(b *bytes.Buffer, v any) {
	switch t := v.(type) {
	case nil:
		b.WriteString("null")
	case bool:
		if t {
			b.WriteString("true")
		} else {
			b.WriteString("false")
		}
	case float64:
		if math.IsNaN(t) || math.IsInf(t, 0) {
			b.WriteString("null")
		} else {
			b.WriteString(FormatNumber(t))
		}
	case string:
		writeString(b, t)
	default:
		panic("jsonx: not a JSON value")
	}
}

func indent(b *bytes.Buffer, depth int) {
	for i := 0; i < depth; i++ {
		b.WriteString("  ")
	}
}

const hexDigits = "0123456789abcdef"

// writeString quotes s as JSON.stringify does: only ", \ and the control
// characters are escaped (\b \t \n \f \r by name, the rest as \u00xx), and
// everything else, U+2028/2029 included, is written as is. Invalid UTF-8
// (which a decoded value never holds) is written as U+FFFD.
func writeString(b *bytes.Buffer, s string) {
	b.WriteByte('"')
	for i := 0; i < len(s); {
		c := s[i]
		if c < utf8.RuneSelf {
			switch c {
			case '"':
				b.WriteString(`\"`)
			case '\\':
				b.WriteString(`\\`)
			case '\b':
				b.WriteString(`\b`)
			case '\t':
				b.WriteString(`\t`)
			case '\n':
				b.WriteString(`\n`)
			case '\f':
				b.WriteString(`\f`)
			case '\r':
				b.WriteString(`\r`)
			default:
				if c < 0x20 {
					b.WriteString(`\u00`)
					b.WriteByte(hexDigits[c>>4])
					b.WriteByte(hexDigits[c&0xf])
				} else {
					b.WriteByte(c)
				}
			}
			i++
			continue
		}
		r, size := utf8.DecodeRuneInString(s[i:])
		if r == utf8.RuneError && size == 1 {
			b.WriteString("�")
		} else {
			b.WriteString(s[i : i+size])
		}
		i += size
	}
	b.WriteByte('"')
}
