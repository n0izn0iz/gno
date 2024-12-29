package userauth

import (
	"path"
	"std"
	"strings"

	"gno.land/p/demo/auth"
	"gno.land/p/demo/ufmt"
	"gno.land/r/demo/authreg"
	"gno.land/r/demo/callerauth"
	rusers "gno.land/r/demo/users"
)

var source std.Realm

type token struct {
	username string
	subToken auth.Token
}

func init() {
	source = std.CurrentRealm()
	authreg.Register(Authenticate)
}

func (t *token) Source() std.Realm {
	return source
}

type AuthSpec struct {
	Provider string
	EntityID string
}

var specs = make(map[string]AuthSpec)

// XXX: allow to override the authenticator

func AuthToken(subToken auth.Token, username string) auth.Token {
	user := rusers.GetUserByName(username)
	if user == nil {
		panic("unknown user")
	}

	return &token{username: username, subToken: subToken}
}

func Authenticate(autok auth.Token) string {
	val, ok := autok.(*token)
	if !ok || val == nil {
		panic(auth.ErrInvalidToken)
	}

	spec, ok := specs[val.username]
	if !ok {
		spec = AuthSpec{
			Provider: "gno.land/r/demo/callerauth",
			EntityID: callerauth.EntityID(rusers.GetUserByName(val.username).Address),
		}
	}

	if val.subToken.Source().PkgPath() != spec.Provider {
		panic(auth.ErrInvalidToken)
	}

	entityID := authreg.Authenticate(val.subToken)
	if entityID != spec.EntityID {
		panic(auth.ErrInvalidToken)
	}

	return val.username
}

func SetSpec(autok auth.Token, spec AuthSpec) {
	username := Authenticate(autok)
	specs[username] = spec
}

func EntityID(username string) string {
	return ufmt.Sprintf("/%s/%s", authreg.ProviderSlug(source), username)
}

var authenticators = make(map[string]auth.Authenticator)

func Authenticator(authPath string) (string, auth.Authenticator) {
	if !strings.HasPrefix(authPath, "/u/") {
		panic(ufmt.Errorf("can't resolve non-user auth-path %q", authPath))
	}
	segments := strings.SplitN(path.Clean(authPath[len("/u/"):]), "/", 2)
	if len(segments) < 1 {
		panic(ufmt.Errorf("missing user segment in auth-path %q", authPath))
	}
	username := segments[0]
	user := rusers.GetUserByName(username)
	if user == nil {
		panic(ufmt.Errorf("unknown user %q", username))
	}
	authenticator := authenticators[user.Name]
	if authenticator == nil {
		authenticator = auth.NewCallerAuth([]std.Address{user.Address})
	}
	return username, auth.ResolveLeaf(authenticator, segments[1])
}
