package validators

import (
	"std"

	"gno.land/p/demo/avl"
	"gno.land/p/nt/poa"
	"gno.land/p/sys/validators"
)

func init() {
	// Prepare the initial validator set
	set := []validators.Validator{
		// samourai-validator
		{
			Address:     std.Address("g16cepxj9zkusk33v4zuknxd7c6e094uszwe35tl"),
			PubKey:      "gpub1pggj7ard9eg82cjtv4u52epjx56nzwgjyg9zq3fgqgejd8fkde50xhz2mxhesv3ffn0qys0m009znfv7lz4sm3l6paz745",
			VotingPower: 1,
		},
	}

	// The default valset protocol is PoA
	vp = poa.NewPoA(poa.WithInitialSet(set))

	// No changes to apply initially
	changes = avl.NewTree()
}
