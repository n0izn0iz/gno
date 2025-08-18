package loader

import (
	"std"

	"gno.land/r/gov/dao"
	"gno.land/r/gov/dao/v3/impl"
	"gno.land/r/gov/dao/v3/memberstore"
)

// this is only executed when loaded into genesis
func init() {
	memberstore.Get().SetTier(memberstore.T1)
	memberstore.Get().SetMember(memberstore.T1, std.Address("g1747t5m2f08plqjlrjk2q0qld7465hxz8gkx59c"), &memberstore.Member{InvitationPoints: 3}) // zxxma
	memberstore.Get().SetMember(memberstore.T1, std.Address("g16jv3rpz7mkt0gqulxas56se2js7v5vmc6n6e0r"), &memberstore.Member{InvitationPoints: 3}) // mikael
	memberstore.Get().SetMember(memberstore.T1, std.Address("g1c4a8e6lc9uuaeqmlsw6gyyxpvun5pjagcc4twr"), &memberstore.Member{InvitationPoints: 3}) // dadidou
	memberstore.Get().SetMember(memberstore.T1, std.Address("g1tdjkvapz5jxap6zxf06dxp7g88kad72svpzcu9"), &memberstore.Member{InvitationPoints: 3}) // norman

	memberstore.Get().SetTier(memberstore.T2)
	memberstore.Get().SetMember(memberstore.T2, std.Address("g14vxq5e5pt5sev7rkz2ej438scmxtylnzv5vnkw"), &memberstore.Member{InvitationPoints: 2}) // villaquiranm
	memberstore.Get().SetMember(memberstore.T2, std.Address("g1at2h7kdhz2m9lv6azn54mwu4wl95k94wu90uwj"), &memberstore.Member{InvitationPoints: 2}) // gh0st
	memberstore.Get().SetMember(memberstore.T2, std.Address("g1qfgeankhm8zeh47ftpsea8u8x8p3vsgdhkzawp"), &memberstore.Member{InvitationPoints: 2}) // miosan_desu
	memberstore.Get().SetMember(memberstore.T2, std.Address("g1q40u8vwx9pxp28awwvfzpp09cv69w0v6pxzxhr"), &memberstore.Member{InvitationPoints: 2}) // lours

	memberstore.Get().SetTier(memberstore.T3)
	memberstore.Get().SetMember(memberstore.T3, std.Address("g1jr9fl5jklpc2ul3v3kshekyqn65h6g2dzdrj4z"), &memberstore.Member{InvitationPoints: 1}) // davd
	memberstore.Get().SetMember(memberstore.T3, std.Address("g1lyzdjdjshcg936w689f44d5yzgg7tcg0w3rl62"), &memberstore.Member{InvitationPoints: 1}) // naim
	memberstore.Get().SetMember(memberstore.T3, std.Address("g15xcnvt8mhekqrmgdnjepwlsqpk0z79cp030x3g"), &memberstore.Member{InvitationPoints: 1}) // zelo
	memberstore.Get().SetMember(memberstore.T3, std.Address("g1n7qma7mslv6768avfvh9k2hkp477ykwcvuyh6p"), &memberstore.Member{InvitationPoints: 1}) // pips

	dao.UpdateImpl(cross, dao.UpdateRequest{
		DAO:         impl.GetInstance(),
		AllowedDAOs: []string{"gno.land/r/gov/dao/v3/impl"},
	})
}
