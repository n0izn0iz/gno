// Package authreg provides a permissionless authenticators registry.
//
// Authenticated entities get namespaced with the authenticator address, preventing
// malicious authenticators from impersonating another authenticator.
package authreg

import (
	"errors"
	"path"
	"std"
	"strings"

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

var fns = make(map[string]auth.AuthenticateFn)

// XXX: we could add a slug there
func Register(authenticate auth.AuthenticateFn) {
	caller := std.PrevRealm()
	/*
		XXX: this check makes the linter panic
		if caller.IsUser() {
			panic("can't register from user realm")
		}
	*/
	callerStr := caller.Addr().String()

	if authenticate == nil {
		if _, ok := fns[callerStr]; !ok {
			panic(errors.New("not registered"))
		}

		delete(fns, callerStr)
		std.Emit(
			unregisterEvent,
			"caller", callerStr,
		)
		return
	}

	fns[callerStr] = authenticate
	std.Emit(
		registerEvent,
		"caller", callerStr,
	)
}

func Authenticate(autok auth.Token) string {
	provider := autok.Source().Addr().String()
	authFn, ok := fns[provider]
	if !ok {
		panic(errors.New("unknown auth provider"))
	}

	provider = ProviderSlug(autok.Source())

	// XXX: maybe emit event for audit purposes

	return auth.NamespacedEntityID(provider, authFn(autok))
}

func PathAuthenticator(authPath string) auth.Authenticator {
	authPath = path.Clean(authPath)
	if len(authPath) == 0 || authPath[0] != '/' {
		panic("invalid auth path %q")
	}

	subPath := authPath[1:]
	node := auth.Authenticator(nil)
	for {
		segments := strings.SplitN(subPath, "/", 2)
		node, subPath = GetAuthenticator(segments[0]).Resolve(segments[1])
		if node.IsLeaf() {
			return node
		}
		if node == nil {
			panic(ufmt.Errorf("unknown path %q", authPath))
		}
	}
}

var authenticators = make(map[string]auth.Authenticator)

func GetAuthenticator(name string) auth.Authenticator {
	resolved, ok := reverseVanity[name]
	if !ok {
		resolved = name
	}
	authenticator, ok := authenticators[resolved]
	if !ok {
		panic(ufmt.Errorf("unknown authenticator %q", name))
	}
	return authenticator
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
