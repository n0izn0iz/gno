package users

import (
	"std"

	susers "gno.land/r/sys/users"
)

// pre-registered users
var preRegisteredUsers = []struct {
	Name    string
	Address std.Address
}{
	// system names.
	// the goal is to make them either team/DAO-owned or ownerless.
	{"archives", "g1xlnyjrnf03ju82v0f98ruhpgnquk28knmjfe5k"}, // -> @archives
	{"demo", "g13ek2zz9qurzynzvssyc4sthwppnruhnp0gdz8n"},     // -> @demo
	{"gno", "g19602kd9tfxrfd60sgreadt9zvdyyuudcyxsz8a"},      // -> @gno
	{"gnoland", "g1g3lsfxhvaqgdv4ccemwpnms4fv6t3aq3p5z6u7"},  // -> @gnoland
	{"gnolang", "g1yjlnm3z2630gg5mryjd79907e0zx658wxs9hnd"},  // -> @gnolang
	{"gov", "g1g73v2anukg4ej7axwqpthsatzrxjsh0wk797da"},      // -> @gov
	{"nt", "g15ge0ae9077eh40erwrn2eq0xw6wupwqthpv34l"},       // -> @nt
	{"sys", "g1r929wt2qplfawe4lvqv9zuwfdcz4vxdun7qh8l"},      // -> @sys
	{"x", "g164sdpew3c2t3rvxj3kmfv7c7ujlvcw2punzzuz"},        // -> @x

	// test1 user
	{"test1", "g1jg8mtutu9khhfwc4nxmuhcpftf0pajdhfvsqf5"}, // -> @test1

	// samourai
	{"samcrew", "g1kfd9f5zlvcvy6aammcmqswa7cyjpu2nyt9qfen"},
	{"davd", "g1jr9fl5jklpc2ul3v3kshekyqn65h6g2dzdrj4z"},
	{"mikael", "g16jv3rpz7mkt0gqulxas56se2js7v5vmc6n6e0r"},
	{"dadidou", "g1c4a8e6lc9uuaeqmlsw6gyyxpvun5pjagcc4twr"},
	{"norman", "g1tdjkvapz5jxap6zxf06dxp7g88kad72svpzcu9"},
	{"lours", "g1q40u8vwx9pxp28awwvfzpp09cv69w0v6pxzxhr"},
	{"villaquiranm", "g14vxq5e5pt5sev7rkz2ej438scmxtylnzv5vnkw"},
	{"miosan_desu", "g1qfgeankhm8zeh47ftpsea8u8x8p3vsgdhkzawp"},
	{"zelo", "g15xcnvt8mhekqrmgdnjepwlsqpk0z79cp030x3g"},
}

func init() {
	// add pre-registered users
	for _, res := range preRegisteredUsers {
		// Try registering, skip if it fails
		susers.RegisterUser(cross, res.Name, res.Address)
	}
}
