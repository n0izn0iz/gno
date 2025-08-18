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
			Address:     std.Address("g1qyxag299pt969w0ml0wqyl234px8hyqgnhmd8m"),
			PubKey:      "gpub1pggj7ard9eg82cjtv4u52epjx56nzwgjyg9zq3mmr8tz3ctazcmmyh473wx9tpde9ynuxfqt8aeyuk03n3dalk8uug9dqz",
			VotingPower: 1,
		},
	}

	// The default valset protocol is PoA
	vp = poa.NewPoA(poa.WithInitialSet(set))

	// No changes to apply initially
	changes = avl.NewTree()
}
