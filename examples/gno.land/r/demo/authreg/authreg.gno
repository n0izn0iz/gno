// Package authreg provides a permissionless authenticators registry.
//
// Authenticated entities get namespaced with the authenticator address, preventing
// malicious authenticators from impersonating another authenticator.
package authreg

import (
	"errors"
	"std"

	"gno.land/p/demo/auth"
	"gno.land/p/demo/ufmt"
)

// XXX: manage with govdao
var vanity = map[string]string{
	"gno.land/r/demo/userauth": "u",
	"gno.land/r/demo/subacc":   "s",

	// debug
	"gno.land/r/demo/callerauth": "call",
	"gno.land/r/demo/sessions":   "sess",
}

var reverseVanity = func() map[string]string {
	reverse := make(map[string]string, len(vanity))
	for key, val := range vanity {
		reverse[val] = key
	}
	return reverse
}()

var authenticators = make(map[string]func() auth.Authenticator)

// XXX: we could add a slug there
func Register(authenticator func() auth.Authenticator) {
	caller := std.PrevRealm()
	/*
		XXX: this check makes the linter panic
		if caller.IsUser() {
			panic("can't register from user realm")
		}
	*/
	callerStr := caller.Addr().String()

	if authenticator == nil {
		if _, ok := authenticators[callerStr]; !ok {
			panic(errors.New("not registered"))
		}

		delete(authenticators, callerStr)
		std.Emit(
			unregisterEvent,
			"caller", callerStr,
		)
		return
	}

	authenticators[callerStr] = authenticator
	std.Emit(
		registerEvent,
		"caller", callerStr,
	)
}

func Resolve(name string) auth.Authenticator {
	resolved, ok := reverseVanity[name]
	if ok {
		resolved = std.DerivePkgAddr(resolved).String()
	} else {
		resolved = name
	}
	authenticator, ok := authenticators[resolved]
	if !ok {
		panic(ufmt.Errorf("unknown authenticator %q (%q)", name, resolved))
	}
	return authenticator()
}

func ProviderSlug(provider std.Realm) string {
	if van, ok := vanity[provider.PkgPath()]; ok {
		return van
	}
	return provider.Addr().String()
}

const (
	registerEvent   = "register"
	unregisterEvent = "unregister"
)
