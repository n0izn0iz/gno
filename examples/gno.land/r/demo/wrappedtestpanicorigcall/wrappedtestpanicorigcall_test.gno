package wrappedtestpanicorigcall

import (
	"std"
	"testing"

	"gno.land/p/demo/urequire"
)

func TestFoo(t *testing.T) {
	std.AssertOriginCall() // does not panic, expected

	urequire.NotPanics(t, func() {
		std.AssertOriginCall() // panics while it should not
	})
}
