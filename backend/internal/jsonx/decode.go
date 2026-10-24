package jsonx

import (
	"fmt"
	"strconv"
	"unicode/utf16"
	"unicode/utf8"
)

// DefaultMaxDepth bounds nesting for input from outside (a config nests a
// dozen levels; this only stops a hostile file or request from exhausting
// the stack).
const DefaultMaxDepth = 256

// SyntaxError is a parse failure at a byte offset.
type SyntaxError struct {
	Offset int
	Msg    string
}

func (e *SyntaxError) Error() string {
	return fmt.Sprintf("invalid JSON at byte %d: %s", e.Offset, e.Msg)
}

// Unmarshal parses data as JSON.parse does: strict JSON, numbers as
// float64, a repeated key keeping its first place with its last value. A
// lone surrogate escape becomes U+FFFD (Go strings are UTF-8).
func Unmarshal(data []byte) (any, error) {
	return UnmarshalDepth(data, DefaultMaxDepth)
}

// UnmarshalDepth is Unmarshal with a nesting limit.
func UnmarshalDepth(data []byte, maxDepth int) (any, error) {
	p := parser{data: data, maxDepth: maxDepth}
	p.skipSpace()
	v, err := p.value(0)
	if err != nil {
		return nil, err
	}
	p.skipSpace()
	if p.pos != len(p.data) {
		return nil, p.errorf("unexpected data after the value")
	}
	return v, nil
}

type parser struct {
	data     []byte
	pos      int
	maxDepth int
}

func (p *parser) errorf(format string, args ...any) error {
	return &SyntaxError{Offset: p.pos, Msg: fmt.Sprintf(format, args...)}
}

func (p *parser) skipSpace() {
	for p.pos < len(p.data) {
		switch p.data[p.pos] {
		case ' ', '\t', '\n', '\r':
			p.pos++
		default:
			return
		}
	}
}

func (p *parser) value(depth int) (any, error) {
	if p.pos >= len(p.data) {
		return nil, p.errorf("unexpected end of input")
	}
	switch c := p.data[p.pos]; {
	case c == '{':
		return p.object(depth + 1)
	case c == '[':
		return p.array(depth + 1)
	case c == '"':
		return p.str()
	case c == 't':
		return true, p.literal("true")
	case c == 'f':
		return false, p.literal("false")
	case c == 'n':
		return nil, p.literal("null")
	case c == '-' || (c >= '0' && c <= '9'):
		return p.number()
	default:
		return nil, p.errorf("unexpected character %q", c)
	}
}

func (p *parser) literal(word string) error {
	if len(p.data)-p.pos < len(word) || string(p.data[p.pos:p.pos+len(word)]) != word {
		return p.errorf("expected %s", word)
	}
	p.pos += len(word)
	return nil
}

func (p *parser) object(depth int) (any, error) {
	if depth > p.maxDepth {
		return nil, p.errorf("nested deeper than %d", p.maxDepth)
	}
	p.pos++ // {
	o := NewObject()
	p.skipSpace()
	if p.pos < len(p.data) && p.data[p.pos] == '}' {
		p.pos++
		return o, nil
	}
	for {
		p.skipSpace()
		if p.pos >= len(p.data) || p.data[p.pos] != '"' {
			return nil, p.errorf("expected a key")
		}
		key, err := p.str()
		if err != nil {
			return nil, err
		}
		p.skipSpace()
		if p.pos >= len(p.data) || p.data[p.pos] != ':' {
			return nil, p.errorf("expected ':'")
		}
		p.pos++
		p.skipSpace()
		v, err := p.value(depth)
		if err != nil {
			return nil, err
		}
		o.Set(key.(string), v)
		p.skipSpace()
		if p.pos >= len(p.data) {
			return nil, p.errorf("unexpected end of input")
		}
		switch p.data[p.pos] {
		case ',':
			p.pos++
		case '}':
			p.pos++
			return o, nil
		default:
			return nil, p.errorf("expected ',' or '}'")
		}
	}
}

func (p *parser) array(depth int) (any, error) {
	if depth > p.maxDepth {
		return nil, p.errorf("nested deeper than %d", p.maxDepth)
	}
	p.pos++ // [
	a := &Array{Items: []any{}}
	p.skipSpace()
	if p.pos < len(p.data) && p.data[p.pos] == ']' {
		p.pos++
		return a, nil
	}
	for {
		p.skipSpace()
		v, err := p.value(depth)
		if err != nil {
			return nil, err
		}
		a.Items = append(a.Items, v)
		p.skipSpace()
		if p.pos >= len(p.data) {
			return nil, p.errorf("unexpected end of input")
		}
		switch p.data[p.pos] {
		case ',':
			p.pos++
		case ']':
			p.pos++
			return a, nil
		default:
			return nil, p.errorf("expected ',' or ']'")
		}
	}
}

func (p *parser) number() (any, error) {
	start := p.pos
	if p.data[p.pos] == '-' {
		p.pos++
	}
	digits := func() int {
		n := 0
		for p.pos < len(p.data) && p.data[p.pos] >= '0' && p.data[p.pos] <= '9' {
			p.pos++
			n++
		}
		return n
	}
	if p.pos < len(p.data) && p.data[p.pos] == '0' {
		p.pos++
	} else if digits() == 0 {
		return nil, p.errorf("expected a digit")
	}
	if p.pos < len(p.data) && p.data[p.pos] == '.' {
		p.pos++
		if digits() == 0 {
			return nil, p.errorf("expected a digit after '.'")
		}
	}
	if p.pos < len(p.data) && (p.data[p.pos] == 'e' || p.data[p.pos] == 'E') {
		p.pos++
		if p.pos < len(p.data) && (p.data[p.pos] == '+' || p.data[p.pos] == '-') {
			p.pos++
		}
		if digits() == 0 {
			return nil, p.errorf("expected an exponent")
		}
	}
	// Out of range parses to ±Inf or 0, as JSON.parse does
	f, err := strconv.ParseFloat(string(p.data[start:p.pos]), 64)
	if err != nil {
		if ne, ok := err.(*strconv.NumError); !ok || ne.Err != strconv.ErrRange {
			return nil, p.errorf("bad number")
		}
	}
	return f, nil
}

func (p *parser) str() (any, error) {
	p.pos++ // "
	start := p.pos
	// Fast path: no escapes
	for p.pos < len(p.data) {
		c := p.data[p.pos]
		if c == '"' {
			s := p.data[start:p.pos]
			p.pos++
			if utf8.Valid(s) {
				return string(s), nil
			}
			return toValidUTF8(s), nil
		}
		if c == '\\' {
			break
		}
		if c < 0x20 {
			return nil, p.errorf("control character in string")
		}
		p.pos++
	}
	buf := append([]byte(nil), p.data[start:p.pos]...)
	for p.pos < len(p.data) {
		c := p.data[p.pos]
		switch {
		case c == '"':
			p.pos++
			if utf8.Valid(buf) {
				return string(buf), nil
			}
			return toValidUTF8(buf), nil
		case c < 0x20:
			return nil, p.errorf("control character in string")
		case c != '\\':
			buf = append(buf, c)
			p.pos++
			continue
		}
		p.pos++ // backslash
		if p.pos >= len(p.data) {
			return nil, p.errorf("unexpected end of input")
		}
		esc := p.data[p.pos]
		p.pos++
		switch esc {
		case '"', '\\', '/':
			buf = append(buf, esc)
		case 'b':
			buf = append(buf, '\b')
		case 'f':
			buf = append(buf, '\f')
		case 'n':
			buf = append(buf, '\n')
		case 'r':
			buf = append(buf, '\r')
		case 't':
			buf = append(buf, '\t')
		case 'u':
			r, err := p.hex4()
			if err != nil {
				return nil, err
			}
			if utf16.IsSurrogate(r) {
				// A pair is one character; a lone half has no UTF-8 form
				if r < 0xDC00 && p.pos+6 <= len(p.data) && p.data[p.pos] == '\\' && p.data[p.pos+1] == 'u' {
					save := p.pos
					p.pos += 2
					r2, err := p.hex4()
					if err == nil && r2 >= 0xDC00 && r2 <= 0xDFFF {
						r = utf16.DecodeRune(r, r2)
					} else {
						p.pos = save
						r = utf8.RuneError
					}
				} else {
					r = utf8.RuneError
				}
			}
			buf = utf8.AppendRune(buf, r)
		default:
			return nil, p.errorf("bad escape \\%c", esc)
		}
	}
	return nil, p.errorf("unterminated string")
}

func (p *parser) hex4() (rune, error) {
	if p.pos+4 > len(p.data) {
		return 0, p.errorf("short \\u escape")
	}
	var r rune
	for _, c := range p.data[p.pos : p.pos+4] {
		r <<= 4
		switch {
		case c >= '0' && c <= '9':
			r |= rune(c - '0')
		case c >= 'a' && c <= 'f':
			r |= rune(c - 'a' + 10)
		case c >= 'A' && c <= 'F':
			r |= rune(c - 'A' + 10)
		default:
			return 0, p.errorf("bad \\u escape")
		}
	}
	p.pos += 4
	return r, nil
}

func toValidUTF8(b []byte) string {
	out := make([]byte, 0, len(b))
	for len(b) > 0 {
		r, size := utf8.DecodeRune(b)
		out = utf8.AppendRune(out, r) // RuneError for invalid bytes
		b = b[size:]
	}
	return string(out)
}
