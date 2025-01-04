package payrolls

import (
	"std"

	"gno.land/p/demo/unicoin"
)

func addCoins(a unicoin.Unicoins, b unicoin.Unicoins) unicoin.Unicoins {
	res := unicoin.Unicoins{}
	for kind, coins := range a {
		res[kind] = make(std.Coins, len(coins))
		copy(res[kind], coins)
	}
	for kind, coins := range b {
		for _, coin := range coins {
			res[kind] = addCoinAmount(res[kind], coin)
		}
	}
	return res
}

func subCoins(a unicoin.Unicoins, b unicoin.Unicoins) unicoin.Unicoins {
	res := unicoin.Unicoins{}
	for kind, coins := range a {
		res[kind] = make(std.Coins, len(coins))
		copy(res[kind], coins)
	}
	for kind, coins := range b {
		for _, coin := range coins {
			res[kind] = addCoinAmount(res[kind], std.NewCoin(coin.Denom, -coin.Amount))
		}
	}
	return res
}

func coinsHasPositive(ucs unicoin.Unicoins) bool {
	for _, coins := range ucs {
		for _, coin := range coins {
			if coin.Amount > 0 {
				return true
			}
		}
	}
	return false
}

func clampCoins(a unicoin.Unicoins, max unicoin.Unicoins) unicoin.Unicoins {
	res := unicoin.Unicoins{}
	for kind, coins := range a {
		out := make(std.Coins, len(coins))
		for _, coin := range coins {
			maxAmount := max[kind].AmountOf(coin.Denom)
			if coin.Amount > maxAmount {
				out = append(out, std.NewCoin(coin.Denom, maxAmount))
				continue
			}
			out = append(out, coin)
		}
		res[kind] = out
	}
	return res
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

func unicoinsEmpty(ucs unicoin.Unicoins) bool {
	for _, coins := range ucs {
		if !coinsEmpty(coins) {
			return false
		}
	}
	return true
}

func coinsEmpty(coins std.Coins) bool {
	for _, coin := range coins {
		if coin.Amount != 0 {
			return false
		}
	}
	return true
}
