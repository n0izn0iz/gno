package auth

import (
	"errors"
	"path"
	"std"
	"strings"
	"time"

	"gno.land/p/demo/ufmt"
)

type Authenticator interface {
	Child(key string) Authenticator // returns nil if not found
	Authenticate() error
	Children() map[string]Authenticator
	Render() string
}

type ResolveFn func(slug string) Authenticator

func BaseEntityID(authPath string) string {
	// FIXME: this is shady
	cleanPath := strings.TrimPrefix(path.Clean(authPath), "/")
	segments := strings.SplitN(cleanPath, "/", 3)
	if len(segments) < 2 {
		panic(ufmt.Errorf("invalid entity auth path %q", authPath))
	}
	return "/" + segments[0] + "/" + segments[1]
}

func Assert(authenticator Authenticator) {
	if authenticator == nil {
		panic(errors.New("nil authenticator"))
	}
	if err := authenticator.Authenticate(); err != nil {
		panic(err)
	}
}

func AssertPath(authPath string, resolve ResolveFn) {
	leaf := Resolve(authPath, resolve)
	Assert(leaf)
}

func AssertEntity(authPath string, resolve ResolveFn) string {
	leaf := Resolve(authPath, resolve)
	Assert(leaf)
	return BaseEntityID(authPath)
}

func Resolve(authPath string, resolve ResolveFn) Authenticator {
	cleanPath := strings.TrimPrefix(path.Clean(authPath), "/")
	segments := strings.Split(cleanPath, "/")
	if len(segments) == 0 {
		panic(ufmt.Errorf("invalid auth path %q", authPath))
	}
	node := resolve(segments[0])
	if node == nil {
		panic(ufmt.Errorf("unknown auth path %q", segments[0]))
	}
	for i, segment := range segments[1:] {
		node = node.Child(segment)
		if node == nil {
			panic(ufmt.Errorf("unknown auth path %q", path.Join(segments[:i+1]...)))
		}
	}
	return node
}

// Mux
//

type mux struct {
	routes map[string]Authenticator
}

var _ Authenticator = (*mux)(nil)

func (m *mux) SetRoute(key string, auth Authenticator) {
	m.routes[key] = auth
}

func (m *mux) Authenticate() error {
	route, ok := m.routes[""]
	if !ok {
		return errors.New("no default")
	}
	return route.Authenticate()
}

func (m *mux) Child(key string) Authenticator {
	return m.routes[key]
}

func (m *mux) Children() map[string]Authenticator {
	cpy := make(map[string]Authenticator)
	for key, val := range m.routes {
		cpy[key] = val
	}
	return cpy
}

func (m *mux) Render() string {
	buf := strings.Builder{}
	buf.WriteString("mux:\n")
	for key, val := range m.routes {
		buf.WriteString(ufmt.Sprintf("- %s\n", key))
		buf.WriteString(indentLines(val.Render(), "  "))
	}
	return buf.String()
}

func Mux(routes map[string]Authenticator) Authenticator {
	if routes == nil {
		routes = make(map[string]Authenticator)
	}
	return &mux{
		routes: routes,
	}
}

// PrevRealms
//

type prevRealms struct {
	allowed map[std.Address]struct{}
}

var _ Authenticator = (*prevRealms)(nil)

func (pr *prevRealms) Authenticate() error {
	caller := std.PrevRealm().Addr()
	if _, ok := pr.allowed[caller]; ok {
		return ufmt.Errorf("%q is not an allowed caller", caller)
	}
	return nil
}

func (pr *prevRealms) Child(key string) Authenticator {
	return nil
}

func (pr *prevRealms) Children() map[string]Authenticator {
	return nil
}

func (pr *prevRealms) Render() string {
	if len(pr.allowed) == 0 {
		return "caller: none\n"
	}

	if len(pr.allowed) == 1 {
		for key := range pr.allowed {
			return ufmt.Sprintf("caller: %s\n", key.String())
		}
	}

	buf := strings.Builder{}
	buf.WriteString("callers:\n")
	for key := range pr.allowed {
		buf.WriteString(ufmt.Sprintf("- %s\n", key))
	}
	return buf.String()
}

func PrevRealms(allowed ...std.Address) Authenticator {
	addrsMap := make(map[std.Address]struct{}, len(allowed))
	for _, addr := range allowed {
		if addr == "" {
			panic("empty addr")
		}
		addrsMap[addr] = struct{}{}
	}
	return &prevRealms{allowed: addrsMap}
}

// EOA
//

type eoa struct {
	child Authenticator
}

var _ Authenticator = (*eoa)(nil)

func (e *eoa) Authenticate() error {
	std.AssertOriginCall()
	if e.child != nil {
		return e.child.Authenticate()
	}
	return nil
}

func (e *eoa) Child(key string) Authenticator {
	return e.child
}

func (e *eoa) Children() map[string]Authenticator {
	return map[string]Authenticator{"": e.child}
}

func (e *eoa) Render() string {
	str := "eoa"
	if e.child != nil {
		str += ": " + e.child.Render()
	}
	return str
}

func EOA(child Authenticator) Authenticator {
	return &eoa{child: child}
}

// EntityRef
//

type entityRef struct {
	id      string
	resolve ResolveFn
}

var _ Authenticator = (*entityRef)(nil)

func (e *entityRef) Authenticate() error {
	return Resolve(e.id, e.resolve).Authenticate()
}

func (e *entityRef) Child(key string) Authenticator {
	return Resolve(e.id, e.resolve)
}

func (e *entityRef) Children() map[string]Authenticator {
	return map[string]Authenticator{"": Resolve(e.id, e.resolve)}
}

func (e *entityRef) Render() string {
	return e.id
}

func EntityRef(id string, resolve ResolveFn) Authenticator {
	if id == "" || resolve == nil {
		panic(errors.New("invalid args"))
	}
	return &entityRef{id: id, resolve: resolve}
}

// Session
//

type session struct {
	child  Authenticator
	expiry time.Time
}

var _ Authenticator = (*session)(nil)

func (s *session) Authenticate() error {
	if !time.Now().Before(s.expiry) {
		return ufmt.Errorf("expired on %s", s.expiry.String())
	}
	return s.child.Authenticate()
}

func (s *session) Child(key string) Authenticator {
	return s.child
}

func (s *session) Children() map[string]Authenticator {
	return map[string]Authenticator{"": s.child}
}

func (s *session) Render() string {
	return ufmt.Sprintf("session [%s]: %s", s.expiry.Format(time.DateTime), s.child.Render())
}

func Session(child Authenticator, expiry time.Time) Authenticator {
	if child == nil || expiry.Unix() == 0 {
		panic(errors.New("invalid args"))
	}
	return &session{child: child, expiry: expiry}
}

// render utils
//

func indentLines(str string, indent string) string {
	lines := strings.Split(str, "\n")
	for i, line := range lines {
		if line == "" {
			continue
		}
		lines[i] = indent + line
	}
	return strings.Join(lines, "\n")
}
