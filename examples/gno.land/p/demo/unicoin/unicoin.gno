package unicoin

import (
	"std"
	"strings"

	"gno.land/p/demo/ufmt"
)

type Kind string

const (
	KindNative Kind = "nat"
)

func (k Kind) String() string {
	return string(k)
}

type Unicoins map[Kind]std.Coins

func (ucs Unicoins) ForEach(fn func(kind Kind, coin std.Coin)) {
	for kind, coins := range ucs {
		for _, coin := range coins {
			fn(kind, coin)
		}
	}
}

func (ucs Unicoins) String() string {
	strs := []string{}
	for kind, coins := range ucs {
		for _, coin := range coins {
			strs = append(strs, ufmt.Sprintf("%d/%s/%s", coin.Amount, kind, coin.Denom))
		}
	}
	return strings.Join(strs, ",")
}

func (ucs Unicoins) Clone() Unicoins {
	if ucs == nil {
		return Unicoins{}
	}
	res := Unicoins{}
	for k, c := range ucs {
		res[k] = make(std.Coins, len(c))
		copy(res[k], c)
	}
	return res
}
