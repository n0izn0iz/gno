package userauth

import (
	"errors"
	"std"
	"strings"

	"gno.land/p/demo/auth"
	"gno.land/p/demo/ufmt"
	"gno.land/r/demo/authreg"
	rusers "gno.land/r/demo/users"
)

var ua *userAuth

func init() {
	ua = &userAuth{authenticators: make(map[string]auth.Authenticator)}
	authreg.Register(func() auth.Authenticator { return ua })
}

func SetAuth(authPath string, authenticator auth.Authenticator) {
	if authenticator == nil {
		panic(errors.New("nil authenticator in SetAuth"))
	}
	prefix := "/" + authreg.ProviderSlug(std.CurrentRealm()) + "/"
	if !strings.HasPrefix(authPath, prefix) {
		panic("can't authenticate from other provider")
	}
	entityID := auth.AssertEntityOfPath(authPath, authreg.Resolve)
	username := strings.TrimPrefix(entityID, prefix)
	println("setting auth for", username, "via", authPath)
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
func (u *userAuth) Authenticate(at auth.Context) error {
	return errors.New("incomplete path")
}

// Child implements auth.Authenticator.
func (u *userAuth) Child(username string) auth.Authenticator {
	println("author", username, u.authenticators[username])
	if _, ok := u.authenticators[username]; !ok {
		usr := rusers.GetUserByName(username)
		if usr == nil {
			panic(ufmt.Errorf("unknown user %s", username))
		}
		u.authenticators[username], _ = auth.Mux(map[string]auth.Authenticator{
			"":     auth.PrevRealms(usr.Address), // XXX: should wrap with EOA authenticator but `run` txs are not considered OriginCalls
			"sess": auth.Sessions(EntityID(username), authreg.Resolve),
		})
	}
	return u.authenticators[username]
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
