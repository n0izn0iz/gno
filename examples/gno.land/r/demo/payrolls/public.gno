// package payrolls is a payroll management example
package payrolls

import (
	"errors"
	"std"
	"time"

	"gno.land/p/demo/avl"
	"gno.land/p/demo/seqid"
	"gno.land/p/demo/unicoin"
	"gno.land/r/demo/grc20reg"
)

var (
	id                    seqid.ID
	uccp                  *unicoin.ContextProvider
	payrolls              avl.Tree                          // seqid.ID -> *payroll
	payrollsByVault       = make(map[string]*avl.Tree)      // vaultID -> seqid.ID -> *payroll
	payrollsByBeneficiary = make(map[std.Address]*avl.Tree) // addr -> seqid.ID -> *payroll
)

func init() {
	uccp = unicoin.NewContextProvider(
		unicoin.NewNativeContext("nat"),
		unicoin.NewGRC20RegContext("20r", grc20reg.Get),
	)
}

// Create creates a new payroll using the vault identified by the caller and namespace.
//
// - distrib is the function used to compute the amount of coins to release at a specific point it time. It must not be nil. Example: [MonthlyContinuous]
//
// - breakup is the function used to manage bonuses when a payroll is terminated. It can be nil. Example: [BreakupCDI]
func Create(namespace string, label string, beneficiary std.Address, distrib DistribFn, breakup BreakupFn) seqid.ID {
	assertValidNamespace(namespace)

	vaultID := vaultIDFromRealm(std.PrevRealm(), namespace)

	if distrib == nil {
		panic(errors.New("nil distrib"))
	}
	if !beneficiary.IsValid() {
		panic(errors.New("invalid beneficiary"))
	}

	p := payroll{
		id:             id.Next(),
		vaultID:        vaultID,
		createdAt:      time.Now(),
		distrib:        distrib,
		breakup:        breakup,
		beneficiary:    beneficiary,
		label:          label,
		creatorAddr:    std.PrevRealm().Addr(),
		breakupCoins:   unicoin.Unicoins{},
		totalWithdrawn: unicoin.Unicoins{},
	}

	payrolls.Set(id.String(), &p)

	if _, ok := payrollsByBeneficiary[p.beneficiary]; !ok {
		payrollsByBeneficiary[p.beneficiary] = avl.NewTree()
	}
	payrollsByBeneficiary[p.beneficiary].Set(p.id.String(), &p)

	if _, ok := payrollsByVault[p.vaultID]; !ok {
		payrollsByVault[p.vaultID] = avl.NewTree()
	}
	payrollsByVault[p.vaultID].Set(p.id.String(), &p)

	return p.id
}

// ClaimAll claims the coins released in the payroll identified by id
//
// - The caller must be the payroll's beneficiary
//
// - If destination is empty, it will send coins to the caller address
func Claim(id seqid.ID, destination std.Address) {
	claimInternal(id, destination, true)
}

func claimInternal(id seqid.ID, destination std.Address, mustClaim bool) bool {
	p := mustGetPayroll(id)
	caller := std.PrevRealm().Addr()
	if caller != p.beneficiary {
		panic(errors.New("only beneficiary can withdraw"))
	}

	vaultAmount := getVaultCoins(p.vaultID)
	claimed := p.claim(vaultAmount)
	if claimed.Empty() {
		if mustClaim {
			panic(errors.New("nothing to claim"))
		} else {
			return false
		}
	}

	if len(destination) == 0 {
		destination = caller
	}

	uccp.Send(std.CurrentRealm().Addr(), destination, claimed)

	vaults.Set(p.vaultID, vaultAmount.Sub(claimed))

	return true
}

// ClaimAll claims the coins released in all payrolls where the caller is the beneficiary
//
// - If destination is empty, it will send coins to the caller address
func ClaimAll(destination std.Address) {
	beneficiary := std.PrevRealm().Addr()
	claimed := false
	payrollsByBeneficiary[beneficiary].Iterate("", "", func(key string, value interface{}) bool {
		p := value.(*payroll)
		if ok := claimInternal(p.id, destination, false); ok {
			claimed = true
		}
		return false
	})
	if !claimed {
		panic(errors.New("nothing to claim"))
	}
}

func Fund(base string, namespace string, coins unicoin.Unicoins) {
	assertValidNamespace(namespace)

	var id string
	if base == "" {
		id = vaultIDFromRealm(std.PrevRealm(), namespace)
	} else {
		var err error
		id, err = vaultID(base, namespace)
		if err != nil {
			panic(err)
		}
	}

	uccp.Receive(coins)
	vaults.Set(id, getVaultCoins(id).Add(coins))
}

func FundFromArgs(base string, namespace string, uniarg string) {
	coins := uccp.FromArg(uniarg, std.PrevRealm().Addr(), std.CurrentRealm().Addr(), true)
	Fund(base, namespace, coins)
}

func WithdrawFunds(namespace string, coins unicoin.Unicoins, destination std.Address) {
	assertValidNamespace(namespace)

	prevRealm := std.PrevRealm()
	if len(destination) == 0 {
		destination = prevRealm.Addr()
	}

	id := vaultIDFromRealm(prevRealm, namespace)

	vaultCoins := getVaultCoins(id).Clone()
	payrollsByVault[id].Iterate("", "", func(key string, value interface{}) bool {
		vaultCoins = vaultCoins.Sub(value.(*payroll).available())
		return false
	})
	vaultCoins = vaultCoins.ClampMin(unicoin.Unicoins{})

	if coins == nil {
		coins = vaultCoins
	} else {
		coins.ClampMax(vaultCoins)
		coins.FillAnys(vaultCoins)
	}

	uccp.Send(std.CurrentRealm().Addr(), destination, coins)
	vaults.Set(id, getVaultCoins(id).Sub(coins))
}

func WithdrawFundsFromArgs(namespace string, arg string, destination std.Address) {
	if arg == "" {
		WithdrawFunds(namespace, nil, destination)
		return
	}
	coins := uccp.FromArg(arg, std.CurrentRealm().Addr(), destination, false)
	WithdrawFunds(namespace, coins, destination)
}

// Stop terminates the payroll identified by id. It will distribute coins using the payroll's breakup function.
func Stop(id seqid.ID) {
	p := mustGetPayroll(id)
	p.stop(std.PrevRealm().Addr())
}

// Pause pauses the payroll identified by id. The payroll will not release coins during the pause.
func Pause(id seqid.ID) {
	p := mustGetPayroll(id)
	p.pause(std.PrevRealm().Addr())
}

// Resume resumes the paused payroll identified by id.
func Resume(id seqid.ID) {
	p := mustGetPayroll(id)
	p.resume(std.PrevRealm().Addr())
}

func mustGetPayroll(id seqid.ID) *payroll {
	ip, ok := payrolls.Get(id.String())
	if !ok {
		panic(errors.New("no such payroll"))
	}
	return ip.(*payroll)
}
