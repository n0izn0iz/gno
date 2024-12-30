package authreg

import (
	"std"
	"testing"

	"gno.land/p/demo/auth"
	"gno.land/p/demo/urequire"
)

func TestAuthreg(t *testing.T) {
	authRealm := std.NewCodeRealm("gno.land/r/testing/tester")
	unknownRealm := std.NewCodeRealm("gno.land/r/testing/unknown")

	std.TestSetRealm(authRealm)
	ma := &mockAuth{}
	Register(func() auth.Authenticator { return ma })

	// test get
	Resolve(authRealm.Addr().String()).Authenticate()
	urequire.True(t, ma.called)

	// test unknown provider
	urequire.PanicsWithMessage(t, "unknown auth provider", func() {
		Resolve(unknownRealm.Addr().String())
	})

	// test unregistering
	Register(nil)
	urequire.PanicsWithMessage(t, "unknown auth provider", func() {
		Resolve(authRealm.Addr().String())
	})
}

type mockAuth struct {
	called bool
}

var _ auth.Authenticator = (*mockAuth)(nil)

// Authenticate implements auth.Authenticator.
func (m *mockAuth) Authenticate() error {
	m.called = true
	return nil
}

// Child implements auth.Authenticator.
func (m *mockAuth) Child(key string) auth.Authenticator {
	panic("unimplemented")
}

// Children implements auth.Authenticator.
func (m *mockAuth) Children() map[string]auth.Authenticator {
	panic("unimplemented")
}

// Render implements auth.Authenticator.
func (m *mockAuth) Render() string {
	panic("unimplemented")
}
