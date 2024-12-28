package subacc_test

import (
	"testing"

	"gno.land/p/demo/urequire"
	"gno.land/r/demo/subacc"
)

func TestEntityID(t *testing.T) {
	expected := "/s/u/test1/savings"
	urequire.Equal(t, expected, subacc.EntityID("/u/test1", "savings"))
}
