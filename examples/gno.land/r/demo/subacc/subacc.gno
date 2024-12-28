// Package subacc (short for sub-accounts) implements an authenticator based on the calling entity and an user-provided slug.
package subacc

import (
	"path"
	"std"

	"gno.land/p/demo/auth"
	"gno.land/r/demo/authreg"
)

var source std.Realm

func init() {
	source = std.CurrentRealm()
	authreg.Register(Authenticate)
}

// AuthToken constructs an [auth.Token] based on the caller and a slug.
//
// Returned tokens have an entity ID namespaced with the caller address, preventing
// malicious callers from impersonating another address.
func AuthToken(ownerToken auth.Token, slug string) auth.Token {
	return &token{ownerToken: ownerToken, slug: slug}
}

type token struct {
	ownerToken auth.Token
	slug       string
}

func (a *token) Source() std.Realm {
	return source
}

var _ auth.Token = (*token)(nil)

// Authenticate implements [auth.AuthenticateFn]
func Authenticate(autok auth.Token) string {
	val, ok := autok.(*token)
	if !ok || val == nil {
		panic(auth.ErrInvalidToken)
	}

	ownerID := authreg.Authenticate(val.ownerToken)

	return accountID(ownerID, val.slug)
}

var _ auth.AuthenticateFn = Authenticate

// EntityID returns the full entity ID for an address and a slug
func EntityID(owner string, slug string) string {
	return path.Join("/", authreg.ProviderSlug(source), accountID(owner, slug))
}

func accountID(owner string, slug string) string {
	return auth.NamespacedEntityID(owner, slug)
}
