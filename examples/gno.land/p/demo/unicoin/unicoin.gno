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
	res := Unicoins{}
	for k, c := range ucs {
		res[k] = make(std.Coins, len(c))
		copy(res[k], c)
	}
	return res
}

func (a Unicoins) Add(b Unicoins) Unicoins {
	res := a.Clone()
	for kind, coins := range b {
		for _, coin := range coins {
			res[kind] = addCoinAmount(res[kind], coin)
		}
	}
	return res
}

func (a Unicoins) Sub(b Unicoins) Unicoins {
	res := a.Clone()
	for kind, coins := range b {
		for _, coin := range coins {
			res[kind] = addCoinAmount(res[kind], std.NewCoin(coin.Denom, -coin.Amount))
		}
	}
	return res
}

func (ucs Unicoins) HasPositive() bool {
	for _, coins := range ucs {
		for _, coin := range coins {
			if coin.Amount > 0 {
				return true
			}
		}
	}
	return false
}

func (ucs Unicoins) HasNegative() bool {
	for _, coins := range ucs {
		for _, coin := range coins {
			if coin.Amount < 0 {
				return true
			}
		}
	}
	return false
}

func (a Unicoins) ClampMax(max Unicoins) Unicoins {
	res := a.Clone()
	for kind, coins := range res {
		for i, coin := range coins {
			maxAmount := max[kind].AmountOf(coin.Denom)
			if coin.Amount > maxAmount {
				coins[i].Amount = maxAmount
			}
		}
	}
	return res
}

func (a Unicoins) ClampMin(min Unicoins) Unicoins {
	res := a.Clone()
	for kind, coins := range res {
		for i, coin := range coins {
			minAmount := min[kind].AmountOf(coin.Denom)
			if coin.Amount < minAmount {
				coins[i].Amount = minAmount
			}
		}
	}
	return res
}

func (ucs Unicoins) Empty() bool {
	for _, coins := range ucs {
		for _, coin := range coins {
			if coin.Amount != 0 {
				return false
			}
		}
	}
	return true
}

func (ucs Unicoins) AssertLeq(other Unicoins) {
	if ok := ucs.Leq(other); ok {
		return
	}
	panic(ufmt.Errorf("%s is not less than %s", ucs, other))
}

func (ucs Unicoins) Leq(other Unicoins) bool {
	for kind, coins := range ucs {
		for _, coin := range coins {
			if coin.Amount > other[kind].AmountOf(coin.Denom) {
				return false
			}
		}
	}
	return true
}

func (ucs Unicoins) FillAnys(other Unicoins) {
	for kind, coins := range ucs {
		for i := range coins {
			if coins[i].Amount != -1 {
				continue
			}
			coins[i].Amount = other[kind].AmountOf(coins[i].Denom)
		}
	}
}

func (ucs Unicoins) OnlyPositive() bool {
	for _, coins := range ucs {
		for _, coin := range coins {
			if coin.Amount <= 0 {
				return false
			}
		}
	}
	return true
}

func addCoinAmount(coins std.Coins, value std.Coin) std.Coins {
	for i, coin := range coins {
		if coin.Denom != value.Denom {
			continue
		}

		out := make(std.Coins, len(coins))
		copy(out, coins)
		out[i].Amount += value.Amount
		return out
	}

	return append(coins, value)
}
