package render

import (
	"math"
	"math/big"
)

// Math.pow, Math.log and Math.exp as the shell's JS engine gives them
// (glibc's, correctly rounded in practice): computed at 256 bits and
// rounded once, where Go's math functions can be an ulp off, which shows in
// the text the helpers write.

const precision = 256

func newFloat(f float64) *big.Float { return new(big.Float).SetPrec(precision).SetFloat64(f) }

var ln2 = lnSeries(newFloat(2))

// lnSeries is ln(m) as 2·atanh((m-1)/(m+1)), for m near 1
func lnSeries(m *big.Float) *big.Float {
	one := newFloat(1)
	z := new(big.Float).SetPrec(precision).Quo(new(big.Float).Sub(m, one), new(big.Float).Add(m, one))
	z2 := new(big.Float).SetPrec(precision).Mul(z, z)
	sum := new(big.Float).SetPrec(precision).Set(z)
	term := new(big.Float).SetPrec(precision).Set(z)
	limit := new(big.Float).SetMantExp(newFloat(1), -precision)
	for k := 3; ; k += 2 {
		term.Mul(term, z2)
		add := new(big.Float).SetPrec(precision).Quo(term, newFloat(float64(k)))
		sum.Add(sum, add)
		if new(big.Float).Abs(add).Cmp(limit) < 0 {
			break
		}
	}
	return sum.Mul(sum, newFloat(2))
}

// bigLn is ln(x) for x > 0
func bigLn(x *big.Float) *big.Float {
	m := new(big.Float).SetPrec(precision)
	e := x.MantExp(m) // x = m · 2^e, m in [0.5, 1)
	r := lnSeries(m)
	return r.Add(r, new(big.Float).SetPrec(precision).Mul(newFloat(float64(e)), ln2))
}

// bigExp is e^x
func bigExp(x *big.Float) *big.Float {
	// x = k·ln2 + r, |r| ≤ ln2/2
	kf, _ := new(big.Float).Quo(x, ln2).Float64()
	k := math.Round(kf)
	r := new(big.Float).SetPrec(precision).Sub(x, new(big.Float).SetPrec(precision).Mul(newFloat(k), ln2))
	sum := newFloat(1)
	term := newFloat(1)
	limit := new(big.Float).SetMantExp(newFloat(1), -precision)
	for n := 1; ; n++ {
		term.Mul(term, r)
		term.Quo(term, newFloat(float64(n)))
		sum.Add(sum, term)
		if new(big.Float).Abs(term).Cmp(limit) < 0 {
			break
		}
	}
	return sum.SetMantExp(sum, int(k))
}

func finite(fs ...float64) bool {
	for _, f := range fs {
		if math.IsNaN(f) || math.IsInf(f, 0) {
			return false
		}
	}
	return true
}

// pow is Math.pow
func pow(x, y float64) float64 {
	if x <= 0 || y == 0 || !finite(x, y) {
		return math.Pow(x, y)
	}
	l := bigLn(newFloat(x))
	out, _ := bigExp(l.Mul(l, newFloat(y))).Float64()
	return out
}

// log is Math.log
func log(x float64) float64 {
	if x <= 0 || !finite(x) {
		return math.Log(x)
	}
	out, _ := bigLn(newFloat(x)).Float64()
	return out
}
