package config

import (
	"std"

	"gno.land/p/moul/authz"
)

var (
	GnoDevRels = authz.NewMemberAuthority(
		std.Address("g1kfd9f5zlvcvy6aammcmqswa7cyjpu2nyt9qfen"), // @samcrew
		std.Address("g1jr9fl5jklpc2ul3v3kshekyqn65h6g2dzdrj4z"), // @davd
	)
	Auth = authz.NewWithAuthority(GnoDevRels)
)

func Render(_ string) string {
	return Auth.Authority().String()
}
