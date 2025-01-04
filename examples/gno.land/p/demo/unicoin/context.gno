package unicoin

import (
	"errors"
	"math"
	"std"
	"strconv"
	"strings"

	"gno.land/p/demo/grc/grc20"
	"gno.land/p/demo/ufmt"
)

const AnyAmount = int64(-1)

func RenderCoinDefault(coin std.Coin) string {
	return ufmt.Sprintf("%s %d", coin.Amount, coin.Denom)
}

type UnicoinContext interface {
	Kind() Kind
	Send(from std.Address, to std.Address, coins std.Coins)
	Allowance(from std.Address, to std.Address, denoms []string) std.Coins
	Render(coin std.Coin) string
}

type ContextProvider struct {
	contexts map[Kind]UnicoinContext
}

func (ctxprov *ContextProvider) Register(newctx UnicoinContext) {
	kind := newctx.Kind()
	if _, ok := ctxprov.Get(kind); ok {
		panic(errors.New("prefix already registered"))
	}
	ctxprov.contexts[kind] = newctx
}

func (ctxprov *ContextProvider) Get(kind Kind) (UnicoinContext, bool) {
	ctx, ok := ctxprov.contexts[kind]
	return ctx, ok
}

func (ctxprov *ContextProvider) Send(from std.Address, to std.Address, unicoins Unicoins) {
	for kind, coins := range unicoins {
		ctx, ok := ctxprov.Get(kind)
		if !ok {
			panic(ufmt.Errorf("unknown unicoin kind %q", kind))
		}

		ctx.Send(from, to, coins)
	}
}

func (ctxprov *ContextProvider) Receive(ucs Unicoins) {
	caller := std.PrevRealm().Addr()
	realm := std.CurrentRealm().Addr()
	ctxprov.Send(caller, realm, ucs)
}

func (ctxprov *ContextProvider) ReceiveArg(arg string) Unicoins {
	caller := std.PrevRealm().Addr()
	realm := std.CurrentRealm().Addr()
	ucs := ctxprov.FromArg(arg, caller, realm)
	ctxprov.Send(caller, realm, ucs)
	return ucs
}

func (ctxprov *ContextProvider) FromArg(arg string, from std.Address, to std.Address) Unicoins {
	if arg == "" {
		arg = "any/" + KindNative.String()
	}
	parts := strings.Split(arg, ",")
	ucs := Unicoins{}
	for _, part := range parts {
		if part == "any/"+KindNative.String() {
			ctx, ok := ctxprov.Get(KindNative)
			if !ok {
				panic(ufmt.Errorf(`unknown unicoin kind "native"`))
			}
			ucs[KindNative] = ctx.Allowance(from, to, nil)
			continue
		}

		slashIdx := strings.IndexRune(part, '/')
		if slashIdx == -1 {
			panic(errors.New("bad arg"))
		}

		denom := part[slashIdx:]
		unidenom, err := ctxprov.Unidenom(denom)
		if err != nil {
			panic(err)
		}

		amountStr := part[:slashIdx]
		var amount int64
		if amountStr == "any" {
			amount = -1
		} else {
			var err error
			amount, err = strconv.ParseInt(amountStr, 10, 64)
			if err != nil {
				panic(err)
			}
		}

		ucs[unidenom.Kind] = append(ucs[unidenom.Kind], std.NewCoin(unidenom.Subject, amount))
	}

	for kind, coins := range ucs {
		denoms := []string{}
		for _, c := range coins {
			if c.Amount != -1 {
				continue
			}
			denoms = append(denoms, c.Denom)
		}
		ctx, ok := ctxprov.Get(kind)
		if !ok {
			panic(ufmt.Errorf("unknown unicoin kind %q", string(kind)))
		}
		allowances := ctx.Allowance(from, to, denoms)
		for i, c := range coins {
			if c.Amount != -1 {
				continue
			}
			amount := allowances.AmountOf(c.Denom)
			ucs[kind][i].Amount = amount
		}
	}

	return ucs
}

func NewContextProvider(initialContexts ...UnicoinContext) *ContextProvider {
	ctxprov := &ContextProvider{contexts: map[Kind]UnicoinContext{}}
	for _, context := range initialContexts {
		ctxprov.Register(context)
	}
	return ctxprov
}

// native

type nativeContext struct {
	kind Kind
}

// Render implements UnicoinContext.
func (s *nativeContext) Render(coin std.Coin) string {
	return ufmt.Sprintf("%d %s", coin.Amount, coin.Denom)
}

func NewNativeContext(kind Kind) UnicoinContext {
	return &nativeContext{kind: Kind(kind)}
}

// Allowance implements UnicoinContext.
func (s *nativeContext) Allowance(from std.Address, to std.Address, denoms []string) std.Coins {
	switch from {
	case std.GetOrigCaller():
		if std.GetOrigCaller() != std.PrevRealm().Addr() {
			panic("not origin call")
		}
		return std.GetOrigSend()
	case std.CurrentRealm().Addr():
		return std.GetBanker(std.BankerTypeRealmSend).GetCoins(from)
	default:
		panic(errors.New("unknown from address"))
	}
}

// Kind implements UnicoinContext.
func (s *nativeContext) Kind() Kind {
	return s.kind
}

// Send implements UnicoinContext.
func (s *nativeContext) Send(from std.Address, to std.Address, coins std.Coins) {
	switch from {
	case std.GetOrigCaller():
		if std.GetOrigCaller() != std.PrevRealm().Addr() {
			panic("not origin call")
		}
		std.GetBanker(std.BankerTypeOrigSend).SendCoins(std.GetOrigPkgAddr(), to, coins)
	case std.CurrentRealm().Addr():
		std.GetBanker(std.BankerTypeRealmSend).SendCoins(from, to, coins)
	default:
		panic(errors.New("unknown from address"))
	}

}

func (s *nativeContext) bankerType(from std.Address) std.BankerType {
	switch from {
	case std.GetOrigCaller():
		if std.GetOrigCaller() != std.PrevRealm().Addr() {
			panic("not origin call")
		}
		return std.BankerTypeOrigSend
	case std.CurrentRealm().Addr():
		return std.BankerTypeRealmSend
	default:
		panic(errors.New("unknown from address"))
	}
}

var _ UnicoinContext = (*nativeContext)(nil)

// registered grc20s

func NewGRC20RegContext(kind Kind, resolve func(key string) grc20.TokenGetter) UnicoinContext {
	return &grc20RegContext{kind: kind, resolve: resolve}
}

type grc20RegContext struct {
	kind    Kind
	resolve func(key string) grc20.TokenGetter
}

// Render implements UnicoinContext.
func (s *grc20RegContext) Render(coin std.Coin) string {
	token := s.token(coin.Denom)

	amountF := float64(coin.Amount) / float64(math.Pow10(int(token.GetDecimals())))
	amount := ufmt.Sprintf("%g", amountF)

	var denom string
	if strings.HasPrefix(coin.Denom, std.GetChainDomain()) {
		denom = ufmt.Sprintf("[$%s](%s)", token.GetSymbol(), strings.TrimPrefix(coin.Denom, std.GetChainDomain()))
	} else {
		denom = ufmt.Sprintf("$%s", token.GetSymbol())
	}

	return ufmt.Sprintf("%s %s", amount, denom)
}

// Allowance implements UnicoinContext.
func (s *grc20RegContext) Allowance(from std.Address, to std.Address, denoms []string) std.Coins {
	out := std.NewCoins()
	for _, denom := range denoms {
		allowance := s.token(denom).CallerTeller().Allowance(from, to)
		if allowance == 0 {
			continue
		}
		out = append(out, std.NewCoin(denom, int64(allowance)))
	}
	return out
}

// Kind implements UnicoinContext.
func (s *grc20RegContext) Kind() Kind {
	return s.kind
}

// Send implements UnicoinContext.
func (s *grc20RegContext) Send(from std.Address, to std.Address, coins std.Coins) {
	for _, coin := range coins {
		if coin.Amount < 0 {
			panic(errors.New("trying to send negative amount"))
		}
		s.token(coin.Denom).CallerTeller().TransferFrom(from, to, uint64(coin.Amount))
	}
}

func (s *grc20RegContext) token(fqname string) *grc20.Token {
	getter := s.resolve(fqname)
	if getter == nil {
		panic(errors.New("failed to resolve token getter"))
	}
	token := getter()
	if token == nil {
		panic(errors.New("failed to get token"))
	}
	return token
}

var _ UnicoinContext = (*nativeContext)(nil)
