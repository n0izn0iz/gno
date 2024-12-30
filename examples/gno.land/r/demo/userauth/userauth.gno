package userauth

import (
	"errors"
	"std"

	"gno.land/p/demo/auth"
	"gno.land/p/demo/ufmt"
	"gno.land/p/demo/users"
	"gno.land/r/demo/authreg"
	rusers "gno.land/r/demo/users"
)

var ua userAuth

func init() {
	ua = userAuth{authenticators: make(map[string]auth.Authenticator)}
	authreg.Register(func() auth.Authenticator { return &ua })
}

func SetAuth(username string, authenticator auth.Authenticator) {
	auth.Assert(ua.Child(username))
	ua.authenticators[username] = authenticator
}

func EntityID(username string) string {
	return ufmt.Sprintf("/%s/%s", authreg.ProviderSlug(std.CurrentRealm()), username)
}

type userAuth struct {
	authenticators map[string]auth.Authenticator
}

var _ auth.Authenticator = (*userAuth)(nil)

// Authenticate implements auth.Authenticator.
func (u *userAuth) Authenticate() error {
	return errors.New("incomplete path")
}

// Child implements auth.Authenticator.
func (u *userAuth) Child(key string) auth.Authenticator {
	a, ok := u.authenticators[key]
	if !ok {
		return auth.EOA(auth.PrevRealms(rusers.Resolve(users.AddressOrName(key))))
	}
	return a
}

// Children implements auth.Authenticator.
func (u *userAuth) Children() map[string]auth.Authenticator {
	cpy := make(map[string]auth.Authenticator, len(u.authenticators))
	for key, val := range u.authenticators {
		cpy[key] = val
	}
	return cpy
}

// Render implements auth.Authenticator.
func (u *userAuth) Render() string {
	return "users\n"
}
