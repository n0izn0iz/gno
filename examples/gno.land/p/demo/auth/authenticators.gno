package auth

import (
	"path"
	"std"
	"strings"

	"gno.land/p/demo/ufmt"
)

type Authenticator interface {
	Authenticate(slug string)
	IsLeaf() bool
	Child(key string) Authenticator
	Children() []Authenticator
	Key() string
}

func ResolveLeaf(node Authenticator, authPath string) Authenticator {
	leaf := ResolvePath(node, authPath)
	if !leaf.IsLeaf() {
		panic(ufmt.Errorf("auth path %q does not lead to leaf", authPath))
	}
	return leaf
}

func ResolvePath(node Authenticator, authPath string) Authenticator {
	cleanPath := path.Clean(authPath)
	if len(cleanPath) == 0 || cleanPath[0] == '/' {
		panic(ufmt.Errorf("invalid auth path %q", authPath))
	}
	segments := strings.Split(cleanPath, "/")
	for i, segment := range segments {
		node = node.Child(segment)
		if node == nil {
			panic(ufmt.Errorf("unknown auth path %q", strings.Join(segments[:i], "/")))
		}
	}
	return node
}

type CallerAuth struct {
	allowed map[std.Address]struct{}
}

func (ca *CallerAuth) Authenticate(slug string) {
	caller := std.PrevRealm().Addr()
	if _, ok := ca.allowed[caller]; !ok {
		panic(ufmt.Errorf("caller %s is not allowed", caller.String()))
	}
}

func (ca *CallerAuth) IsLeaf() bool {
	return true
}

func (ca *CallerAuth) Children() []Authenticator {
	return nil
}

func (ca *CallerAuth) Child(key string) Authenticator {
	return nil
}

func (ca *CallerAuth) Key() string {
	return "c"
}

func NewCallerAuth(allowed []std.Address) *CallerAuth {
	allowedMap := make(map[std.Address]struct{})
	for _, elem := range allowed {
		allowedMap[elem] = struct{}{}
	}
	return &CallerAuth{allowed: allowedMap}
}

type AuthMux struct {
	key    string
	routes map[string]Authenticator
}

func (sa *AuthMux) Authenticate(p string) {

}

func (sa *AuthMux) SetRoute(auth Authenticator) {
	sa.routes[auth.Key()] = auth
}

func (ca *AuthMux) IsLeaf() bool {
	return false
}

func (ca *AuthMux) Children() []Authenticator {
	children := make([]Authenticator, len(ca.routes))
	for _, route := range ca.routes {
		children = append(children, route)
	}
	return children
}

func (ca *AuthMux) Child(key string) Authenticator {
	return ca.routes[key]
}

func (ca *AuthMux) Key() string {
	return ca.key
}

func NewMux(key string, routes map[string]Authenticator) *AuthMux {
	return &AuthMux{
		key:    key,
		routes: routes,
	}
}
