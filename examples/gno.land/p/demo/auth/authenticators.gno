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
	Authenticate(at Context) error
	Children() map[string]Authenticator
	Render() string
}

type Context interface {
	PrevRealm() std.Realm
}

type context struct {
	prevRealm std.Realm
}

func (at *context) PrevRealm() std.Realm {
	// XXX: this is probably unsecure in many ways but I did not find another way to assert caller
	// only using Assert* functions of this lib to authenticate seems secure
	return at.prevRealm
}

func NewContext() Context {
	return &context{prevRealm: std.PrevRealm()}
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
	at := NewContext()
	if err := authenticator.Authenticate(at); err != nil {
		panic(ufmt.Errorf("auth failed: %s\n%s", err.Error(), authenticator.Render()))
	}
}

func AssertPath(authPath string, resolve ResolveFn) {
	leaf := Resolve(authPath, resolve)
	Assert(leaf)
}

func AssertEntity(authPath string, entityID string, resolve ResolveFn) {
	leaf := Resolve(authPath, resolve)
	Assert(leaf)
	authID := BaseEntityID(authPath)
	if authID != entityID {
		panic(errors.New("entity not authorized"))
	}
}

func AssertEntityOfPath(authPath string, resolve ResolveFn) string {
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
	println("root segment", segments[0])
	node := resolve(segments[0])
	if node == nil {
		panic(ufmt.Errorf("unknown auth root %q", segments[0]))
	}
	for i, segment := range segments[1:] {
		println("segment", segment)
		node = node.Child(segment)
		if node == nil {
			panic(ufmt.Errorf("unknown segment %q in %q", segment, "/"+path.Join(segments[:i+1]...)))
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

func (m *mux) Authenticate(at Context) error {
	route, ok := m.routes[""]
	if !ok {
		return errors.New("no default")
	}
	return route.Authenticate(at)
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
		buf.WriteString(ufmt.Sprintf("- %q: ", key))
		buf.WriteString(indentFollowingLines(val.Render(), "  "))
	}
	return buf.String()
}

func Mux(routes map[string]Authenticator) (Authenticator, *MuxAdmin) {
	if routes == nil {
		routes = make(map[string]Authenticator)
	}
	m := &mux{
		routes: routes,
	}
	return m, &MuxAdmin{mux: m}
}

type MuxAdmin struct {
	mux *mux
}

func (madm *MuxAdmin) Routes() map[string]Authenticator {
	return madm.mux.routes
}

// PrevRealms
//

type prevRealms struct {
	allowed map[std.Address]struct{}
}

var _ Authenticator = (*prevRealms)(nil)

func (pr *prevRealms) Authenticate(at Context) error {
	caller := at.PrevRealm()
	if _, ok := pr.allowed[caller.Addr()]; !ok {
		allowed := []string{}
		for key := range pr.allowed {
			allowed = append(allowed, key.String())
		}
		return ufmt.Errorf("%q (%q) is not an allowed caller, allowed in %q (%q): %s", caller.Addr().String(), caller.PkgPath(), std.CurrentRealm().Addr().String(), std.CurrentRealm().PkgPath(), strings.Join(allowed, ", "))
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

func (e *eoa) Authenticate(at Context) error {
	std.AssertOriginCall()
	if e.child != nil {
		return e.child.Authenticate(at)
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

func (e *entityRef) Authenticate(at Context) error {
	return Resolve(e.id, e.resolve).Authenticate(at)
}

func (e *entityRef) Child(key string) Authenticator {
	return Resolve(e.id, e.resolve)
}

func (e *entityRef) Children() map[string]Authenticator {
	return map[string]Authenticator{"": Resolve(e.id, e.resolve)}
}

func (e *entityRef) Render() string {
	return "entity: " + e.id
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

func (s *session) Authenticate(at Context) error {
	if !time.Now().Before(s.expiry) {
		return ufmt.Errorf("expired on %s", s.expiry.String())
	}
	return s.child.Authenticate(at)
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

// Session
//

type sessions struct {
	mux     *mux
	admin   string
	resolve ResolveFn
}

var _ Authenticator = (*sessions)(nil)

func (s *sessions) Authenticate(at Context) error {
	return errors.New("incomplete auth path")
}

func (s *sessions) Child(key string) Authenticator {
	return s.mux.Child(key)
}

func (s *sessions) Children() map[string]Authenticator {
	return s.mux.Children()
}

func (s *sessions) Render() string {
	return ufmt.Sprintf("sessions %s", s.mux.Render())
}

type SessionsAdm interface {
	Authenticator
	Create(authPath string, key string, child Authenticator, expiry time.Time)
	Drop(key string)
	SudoDrop(authPath string, key string)
	SetAdmin(authPath string, newAdmin string)
}

func (s *sessions) Create(authPath string, key string, child Authenticator, expiry time.Time) {
	if key == "" {
		panic(errors.New("empty key"))
	}
	AssertEntity(authPath, s.admin, s.resolve)
	s.mux.routes[key] = Session(child, expiry)
}

func (s *sessions) Drop(key string) {
	sess := s.mux.routes[key]
	Assert(sess)
	delete(s.mux.routes, key)
}

func (s *sessions) SudoDrop(authPath string, key string) {
	AssertEntity(authPath, s.admin, s.resolve)
	if key == "" {
		s.mux.routes = make(map[string]Authenticator)
		return
	}
	delete(s.mux.routes, key)
}

func (s *sessions) SetAdmin(authPath string, newAdmin string) {
	if newAdmin == "" {
		panic(errors.New("invalid new admin"))
	}
	AssertEntity(authPath, s.admin, s.resolve)
	s.admin = newAdmin
}

func Sessions(admin string, resolve ResolveFn) SessionsAdm {
	return &sessions{admin: admin, resolve: resolve, mux: &mux{routes: make(map[string]Authenticator)}}
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
func indentFollowingLines(str string, indent string) string {
	lines := strings.Split(str, "\n")
	if len(lines) <= 1 {
		return str
	}
	for i, line := range lines[1:] {
		if line == "" {
			continue
		}
		lines[i+1] = indent + line
	}
	return strings.Join(lines, "\n")
}
