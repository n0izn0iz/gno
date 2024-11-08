package load

import (
	"os"
	"path/filepath"
	"testing"

	"github.com/stretchr/testify/require"
)

func TestGetGnoImports(t *testing.T) {
	workingDir, err := os.Getwd()
	require.NoError(t, err)

	// create external dir
	tmpDir, cleanUpFn := createTmpDir(t)
	defer cleanUpFn()

	// cd to tmp directory
	os.Chdir(tmpDir)
	defer os.Chdir(workingDir)

	files := []struct {
		name, data string
	}{
		{
			name: "file1.gno",
			data: `
			package tmp

			import (
				"std"

				"gno.land/p/demo/pkg1"
			)
			`,
		},
		{
			name: "file2.gno",
			data: `
			package tmp

			import (
				"gno.land/p/demo/pkg1"
				"gno.land/p/demo/pkg2"
			)
			`,
		},
		{
			name: "file1_test.gno",
			data: `
			package tmp

			import (
				"testing"

				"gno.land/p/demo/testpkg"
			)
			`,
		},
		{
			name: "z_0_filetest.gno",
			data: `
			package main

			import (
				"gno.land/p/demo/filetestpkg"
			)
			`,
		},

		// subpkg files
		{
			name: filepath.Join("subtmp", "file1.gno"),
			data: `
			package subtmp

			import (
				"std"

				"gno.land/p/demo/subpkg1"
			)
			`,
		},
		{
			name: filepath.Join("subtmp", "file2.gno"),
			data: `
			package subtmp

			import (
				"gno.land/p/demo/subpkg1"
				"gno.land/p/demo/subpkg2"
			)
			`,
		},
	}

	// Expected list of imports
	// - ignore subdirs
	// - ignore duplicate
	// - ignore *_filetest.gno
	// - should be sorted
	expected := []string{
		"gno.land/p/demo/pkg1",
		"gno.land/p/demo/pkg2",
		"gno.land/p/demo/testpkg",
		"std",
		"testing",
	}

	// Create subpkg dir
	err = os.Mkdir("subtmp", 0o700)
	require.NoError(t, err)

	// Create files
	for _, f := range files {
		err = os.WriteFile(f.name, []byte(f.data), 0o644)
		require.NoError(t, err)
	}

	imports, err := GetGnoPackageImports(tmpDir)
	require.NoError(t, err)

	require.Equal(t, expected, imports)
}

func createTmpDir(t *testing.T) (string, func()) {
	t.Helper()

	tmpDir, err := os.MkdirTemp("", "gno-mod-test")
	if err != nil {
		t.Error("Failed to create tmp dir for mod:", err)
	}

	cleanUpFn := func() {
		err := os.RemoveAll(tmpDir)
		if err != nil {
			t.Logf("Failed to clean up test %s: %v", t.Name(), err)
		}
	}

	return tmpDir, cleanUpFn
}
