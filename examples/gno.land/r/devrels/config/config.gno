package config

import (
	"std"

	"gno.land/p/moul/authz"
)

var (
	GnoDevRels = authz.NewMemberAuthority(
		std.Address("g1kfd9f5zlvcvy6aammcmqswa7cyjpu2nyt9qfen"), // @moul
		std.Address("g125em6arxsnj49vx35f0n0z34putv5ty3376fg5"), // @leohhhn
	)
	Auth = authz.NewWithAuthority(GnoDevRels)
)

func Render(_ string) string {
	return Auth.Authority().String()
}
