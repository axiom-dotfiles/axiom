package jsonx

import (
	"math"
	"strconv"
	"strings"
	"unicode/utf16"
)

// JS semantics the ported helpers rely on, for JSON values (no undefined:
// a missing value is reported by the caller's ok flag).

// Truthy is JS truthiness: false, 0, NaN, "" and null are false; every
// object and array is true.
func Truthy(v any) bool {
	switch t := v.(type) {
	case nil:
		return false
	case bool:
		return t
	case float64:
		return t != 0 && !math.IsNaN(t)
	case string:
		return t != ""
	default:
		return true
	}
}

// StrictEqual is JS's ===: same type and value, objects and arrays by
// identity.
func StrictEqual(a, b any) bool {
	switch x := a.(type) {
	case float64:
		y, ok := b.(float64)
		return ok && x == y
	case *Object:
		y, ok := b.(*Object)
		return ok && x == y
	case *Array:
		y, ok := b.(*Array)
		return ok && x == y
	default:
		return a == b
	}
}

// SameValueZero is the equality Array.prototype.includes uses: === except
// that NaN equals NaN.
func SameValueZero(a, b any) bool {
	if x, ok := a.(float64); ok {
		if y, ok := b.(float64); ok && math.IsNaN(x) && math.IsNaN(y) {
			return true
		}
	}
	return StrictEqual(a, b)
}

// ToString is JS's String(v) as template literals use it: numbers as
// Number::toString, arrays joined by "," (null items empty), objects as
// "[object Object]".
func ToString(v any) string {
	switch t := v.(type) {
	case nil:
		return "null"
	case bool:
		if t {
			return "true"
		}
		return "false"
	case float64:
		return FormatNumber(t)
	case string:
		return t
	case *Array:
		return Join(t, ",")
	default:
		return "[object Object]"
	}
}

// Join is Array.prototype.join: each item as String(item), null as "".
func Join(a *Array, sep string) string {
	parts := make([]string, len(a.Items))
	for i, x := range a.Items {
		if x != nil {
			parts[i] = ToString(x)
		}
	}
	return strings.Join(parts, sep)
}

// ToNumber is JS's Number(v) for JSON values.
func ToNumber(v any) float64 {
	switch t := v.(type) {
	case nil:
		return 0
	case bool:
		if t {
			return 1
		}
		return 0
	case float64:
		return t
	case string:
		return stringToNumber(t)
	default:
		// via ToPrimitive: the string form
		return stringToNumber(ToString(v))
	}
}

func stringToNumber(s string) float64 {
	s = strings.TrimFunc(s, isJSSpace)
	if s == "" {
		return 0
	}
	switch s {
	case "Infinity", "+Infinity":
		return math.Inf(1)
	case "-Infinity":
		return math.Inf(-1)
	}
	if len(s) > 2 && s[0] == '0' {
		base := 0
		switch s[1] {
		case 'x', 'X':
			base = 16
		case 'o', 'O':
			base = 8
		case 'b', 'B':
			base = 2
		}
		if base != 0 {
			n, err := strconv.ParseUint(s[2:], base, 64)
			if err != nil || strings.ContainsAny(s[2:], "_+-") {
				return math.NaN()
			}
			return float64(n)
		}
	}
	// A plain decimal literal only (ParseFloat would also take "inf",
	// hex floats and underscores, which Number() doesn't)
	if !isDecimalLiteral(s) {
		return math.NaN()
	}
	f, err := strconv.ParseFloat(s, 64)
	if err != nil {
		if ne, ok := err.(*strconv.NumError); ok && ne.Err == strconv.ErrRange {
			return f
		}
		return math.NaN()
	}
	return f
}

func isDecimalLiteral(s string) bool {
	i := 0
	if i < len(s) && (s[i] == '+' || s[i] == '-') {
		i++
	}
	digits := 0
	for i < len(s) && s[i] >= '0' && s[i] <= '9' {
		i++
		digits++
	}
	if i < len(s) && s[i] == '.' {
		i++
		for i < len(s) && s[i] >= '0' && s[i] <= '9' {
			i++
			digits++
		}
	}
	if digits == 0 {
		return false
	}
	if i < len(s) && (s[i] == 'e' || s[i] == 'E') {
		i++
		if i < len(s) && (s[i] == '+' || s[i] == '-') {
			i++
		}
		exp := 0
		for i < len(s) && s[i] >= '0' && s[i] <= '9' {
			i++
			exp++
		}
		if exp == 0 {
			return false
		}
	}
	return i == len(s)
}

func isJSSpace(r rune) bool {
	switch r {
	case '\t', '\n', '\v', '\f', '\r', ' ', 0xA0, 0x1680, 0x2028, 0x2029, 0x202F, 0x205F, 0x3000, 0xFEFF:
		return true
	}
	return r >= 0x2000 && r <= 0x200A
}

// Less is JS's abstract relational comparison a < b: strings compare as
// strings, anything else as numbers. undefined is true when either side is
// NaN (every comparison is then false).
func Less(a, b any) (less, undefined bool) {
	pa, pb := toPrimitive(a), toPrimitive(b)
	if sa, ok := pa.(string); ok {
		if sb, ok := pb.(string); ok {
			return compareUTF16(sa, sb) < 0, false
		}
	}
	x, y := ToNumber(pa), ToNumber(pb)
	if math.IsNaN(x) || math.IsNaN(y) {
		return false, true
	}
	return x < y, false
}

func toPrimitive(v any) any {
	switch v.(type) {
	case *Object, *Array:
		return ToString(v)
	}
	return v
}

// LessThan is a < b, GreaterThan a > b, LessOrEqual a <= b and
// GreaterOrEqual a >= b, as JS evaluates them.
func LessThan(a, b any) bool {
	l, _ := Less(a, b)
	return l
}

func GreaterThan(a, b any) bool {
	l, _ := Less(b, a)
	return l
}

func LessOrEqual(a, b any) bool {
	l, undef := Less(b, a)
	return !undef && !l
}

func GreaterOrEqual(a, b any) bool {
	l, undef := Less(a, b)
	return !undef && !l
}

// compareUTF16 orders strings by UTF-16 code units, as JS does (UTF-8 byte
// order differs only between astral characters and U+E000–U+FFFF).
func compareUTF16(a, b string) int {
	ua, ub := utf16.Encode([]rune(a)), utf16.Encode([]rune(b))
	for i := 0; i < len(ua) && i < len(ub); i++ {
		if ua[i] != ub[i] {
			if ua[i] < ub[i] {
				return -1
			}
			return 1
		}
	}
	return len(ua) - len(ub)
}
