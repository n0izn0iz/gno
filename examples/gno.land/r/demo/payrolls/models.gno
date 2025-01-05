package payrolls

import (
	"errors"
	"std"
	"time"

	"gno.land/p/demo/seqid"
	"gno.land/p/demo/unicoin"
)

// XXX: should pass a read-only payroll object to those funcs

// DistribFn is a distribution function used to compute and amount of released coins at a particular point in time.
//
// It must return payrolls [Coins]
type DistribFn func(worked time.Duration) unicoin.Unicoins

// BreakupFn is a function used to compute payroll termination bonuses.
//
// It must return payrolls [Coins]
type BreakupFn func(elapsed time.Duration, pauseDuration time.Duration, source CallSource) unicoin.Unicoins

// DistribStep returns a distribution function that will release coins every `per` duration.
func DistribStep(ucs unicoin.Unicoins, per time.Duration) DistribFn {
	if !ucs.OnlyPositive() {
		panic(errors.New("negative amount"))
	}
	return func(elapsed time.Duration) unicoin.Unicoins {
		blocksCount := elapsed / per
		res := unicoin.Unicoins{}
		for kind, coins := range ucs {
			out := make(std.Coins, 0, len(coins))
			for _, coin := range coins {
				out = append(out, std.NewCoin(coin.Denom, coin.Amount*int64(blocksCount)))
			}
			res[kind] = out
		}
		return res
	}
}

// DistribLinear returns a distribution function that will continuously release coins every seconds and amount to a rate of `coins` every `per` duration.
func DistribLinear(ucs unicoin.Unicoins, per time.Duration) DistribFn {
	if !ucs.OnlyPositive() {
		panic(errors.New("negative amount"))
	}
	return func(elapsed time.Duration) unicoin.Unicoins {
		res := unicoin.Unicoins{}
		for kind, coins := range ucs {
			out := make(std.Coins, 0, len(coins))
			for _, coin := range coins {
				newAmount := (int64(elapsed.Seconds()) * coin.Amount) / int64(per.Seconds())
				out = append(out, std.NewCoin(coin.Denom, newAmount))
			}
			res[kind] = out
		}
		return res
	}
}

// DistribMonthlyStep returns a distribution function that will release `coins` every months
func DistribMonthlyStep(amountPerMonth unicoin.Unicoins) DistribFn {
	return DistribStep(amountPerMonth, time.Hour*24*30)
}

// DistribMonthlyStep returns a distribution function that will continuously release coins every seconds and amount to a rate of `coins` every months
func DistribMonthlyContinuous(amountPerMonth unicoin.Unicoins) DistribFn {
	return DistribLinear(amountPerMonth, time.Hour*24*30)
}

// CreateMonthlyContinuous creates a payroll with a continuous release at a fixed rate per months of a token identified by denom.
//
// denom must be a payrolls [Coins] denom
func CreateMonthlyContinuous(namespace string, label string, beneficiary std.Address, amountPerMonth string) seqid.ID {
	coinsPerMonth := uccp.FromArg(amountPerMonth, std.PrevRealm().Addr(), beneficiary, false)
	return Create(namespace, label, beneficiary, DistribMonthlyContinuous(coinsPerMonth), nil)
}

// CreateCDI creates a payroll that tries to match the French CDI contract
//
// Denom must be a payrolls [Coins] denom
//
// See: https://travail-emploi.gouv.fr/le-contrat-de-travail-duree-indeterminee-cdi
func CreateCDI(namespace string, label string, beneficiary std.Address, amountPerMonth string) seqid.ID {
	coinsPerMonth := uccp.FromArg(amountPerMonth, std.PrevRealm().Addr(), beneficiary, false)
	return Create(namespace, label, beneficiary, DistribMonthlyStep(coinsPerMonth), BreakupCDI(coinsPerMonth))
}

// BreakupCDI is a breakup function that will release an amount of coins
// according to a simplified "Rupture Conventionelle" (conventional breakup) model based on the French CDI employment contract
func BreakupCDI(coinsPerMonth unicoin.Unicoins) BreakupFn {
	const hoursPerYear = float64(8_670)
	return func(elapsed time.Duration, pauseDuration time.Duration, source CallSource) unicoin.Unicoins {
		if source != CallSourceCreator {
			return unicoin.Unicoins{}
		}

		// conventional breakup
		worked := elapsed - pauseDuration
		numYears := worked.Hours() / hoursPerYear
		res := unicoin.Unicoins{}
		for kind, coins := range coinsPerMonth {
			out := make(std.Coins, 0, len(coins))
			for _, coin := range coins {
				newAmount := int64(0.25 * float64(coin.Amount) * numYears)
				out = append(out, std.NewCoin(coin.Denom, newAmount))
			}
			res[kind] = out
		}
		return res
	}
}
