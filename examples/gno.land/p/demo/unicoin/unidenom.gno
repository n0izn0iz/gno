package unicoin

import (
	"errors"
	"strings"

	"gno.land/p/demo/ufmt"
)

type Unidenom struct {
	Kind    Kind
	Subject string
}

func (prov *ContextProvider) Unidenom(input string) (*Unidenom, error) {
	if len(input) == 0 {
		return nil, errors.New("empty input")
	}
	if input[0] != '/' {
		return nil, errors.New("input must start with slash")
	}

	secondSlashIdx := strings.IndexRune(input[1:], '/')
	if secondSlashIdx == -1 {
		return nil, errors.New("input must have at least 2 slashes")
	}
	secondSlashIdx += 1
	if secondSlashIdx == len(input)-1 {
		return nil, errors.New("subject empty")
	}
	subject := input[secondSlashIdx+1:]

	kind := Kind(input[1:secondSlashIdx])
	if _, ok := prov.Get(kind); !ok {
		panic(ufmt.Errorf("unknown unidenom kind %q", string(kind)))
	}

	return &Unidenom{Kind: kind, Subject: subject}, nil
}
