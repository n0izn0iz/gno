package callerauth

import (
	"path"
	"std"

	"gno.land/p/demo/auth"
	"gno.land/r/demo/authreg"
)

var source std.Realm

type token struct {
	caller std.Address
}

func init() {
	source = std.CurrentRealm()
	authreg.Register(Authenticate)
}

func (t *token) Source() std.Realm {
	return source
}

func AuthToken() auth.Token {
	caller := std.PrevRealm().Addr()
	return &token{caller: caller}
}

func Authenticate(autok auth.Token) string {
	val, ok := autok.(*token)
	if !ok || val == nil {
		panic(auth.ErrInvalidToken)
	}

	return val.caller.String()
}

func EntityID(caller std.Address) string {
	return path.Join("/", authreg.ProviderSlug(source), caller.String())
}
