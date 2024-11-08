package load

import (
	"fmt"
	"io/fs"
	"os"
	"path/filepath"
	"regexp"
	"strings"
)

func IsGnoFile(f fs.DirEntry) bool {
	name := f.Name()
	return !strings.HasPrefix(name, ".") && strings.HasSuffix(name, ".gno") && !f.IsDir()
}

func GnoFilesFromArgsRecursively(args []string) ([]string, error) {
	var paths []string

	for _, argPath := range args {
		info, err := os.Stat(argPath)
		if err != nil {
			return nil, fmt.Errorf("invalid file or package path: %w", err)
		}

		if !info.IsDir() {
			if IsGnoFile(fs.FileInfoToDirEntry(info)) {
				paths = append(paths, ensurePathPrefix(argPath))
			}

			continue
		}

		err = walkDirForGnoDirs(argPath, func(path string) {
			dir := ensurePathPrefix(path)
			files, err := os.ReadDir(dir)
			if err != nil {
				return
			}
			for _, f := range files {
				if IsGnoFile(f) {
					path := filepath.Join(dir, f.Name())
					paths = append(paths, ensurePathPrefix(path))
				}
			}
		})
		if err != nil {
			return nil, fmt.Errorf("unable to walk dir: %w", err)
		}
	}

	return paths, nil
}

func GnoDirsFromArgsRecursively(args []string) ([]string, error) {
	var paths []string

	for _, argPath := range args {
		info, err := os.Stat(argPath)
		if err != nil {
			return nil, fmt.Errorf("invalid file or package path: %w", err)
		}

		if !info.IsDir() {
			if IsGnoFile(fs.FileInfoToDirEntry(info)) {
				paths = append(paths, ensurePathPrefix(argPath))
			}

			continue
		}

		// Gather package paths from the directory
		err = walkDirForGnoDirs(argPath, func(path string) {
			paths = append(paths, ensurePathPrefix(path))
		})
		if err != nil {
			return nil, fmt.Errorf("unable to walk dir: %w", err)
		}
	}

	return paths, nil
}

func GnoFilesFromArgs(args []string) ([]string, error) {
	var paths []string

	for _, argPath := range args {
		info, err := os.Stat(argPath)
		if err != nil {
			return nil, fmt.Errorf("invalid file or package path: %w", err)
		}

		if !info.IsDir() {
			if IsGnoFile(fs.FileInfoToDirEntry(info)) {
				paths = append(paths, ensurePathPrefix(argPath))
			}
			continue
		}

		files, err := os.ReadDir(argPath)
		if err != nil {
			return nil, err
		}
		for _, f := range files {
			if IsGnoFile(f) {
				path := filepath.Join(argPath, f.Name())
				paths = append(paths, ensurePathPrefix(path))
			}
		}
	}

	return paths, nil
}

func ensurePathPrefix(path string) string {
	if filepath.IsAbs(path) {
		return path
	}

	// cannot use path.Join or filepath.Join, because we need
	// to ensure that ./ is the prefix to pass to go build.
	// if not absolute.
	return "." + string(filepath.Separator) + path
}

func walkDirForGnoDirs(root string, addPath func(path string)) error {
	visited := make(map[string]struct{})

	walkFn := func(currPath string, f fs.DirEntry, err error) error {
		if err != nil {
			return fmt.Errorf("%s: walk dir: %w", root, err)
		}

		if f.IsDir() || !IsGnoFile(f) {
			return nil
		}

		parentDir := filepath.Dir(currPath)
		if _, found := visited[parentDir]; found {
			return nil
		}

		visited[parentDir] = struct{}{}

		addPath(parentDir)

		return nil
	}

	return filepath.WalkDir(root, walkFn)
}

func GnoPackagesFromArgsRecursively(args []string) ([]string, error) {
	var paths []string

	for _, argPath := range args {
		info, err := os.Stat(argPath)
		if err != nil {
			return nil, fmt.Errorf("invalid file or package path: %w", err)
		}

		if !info.IsDir() {
			paths = append(paths, ensurePathPrefix(argPath))

			continue
		}

		// Gather package paths from the directory
		err = walkDirForGnoDirs(argPath, func(path string) {
			paths = append(paths, ensurePathPrefix(path))
		})
		if err != nil {
			return nil, fmt.Errorf("unable to walk dir: %w", err)
		}
	}

	return paths, nil
}

// targetsFromPatterns returns a list of target paths that match the patterns.
// Each pattern can represent a file or a directory, and if the pattern
// includes "/...", the "..." is treated as a wildcard, matching any string.
// Intended to be used by gno commands such as `gno test`.
func TargetsFromPatterns(patterns []string) ([]string, error) {
	paths := []string{}
	for _, p := range patterns {
		var match func(string) bool
		patternLookup := false
		dirToSearch := p

		// Check if the pattern includes `/...`
		if strings.Contains(p, "/...") {
			index := strings.Index(p, "/...")
			if index != -1 {
				dirToSearch = p[:index] // Extract the directory path to search
			}
			match = matchPattern(strings.TrimPrefix(p, "./"))
			patternLookup = true
		}

		info, err := os.Stat(dirToSearch)
		if err != nil {
			return nil, fmt.Errorf("invalid file or package path: %w", err)
		}

		// If the pattern is a file or a directory
		// without `/...`, add it to the list.
		if !info.IsDir() || !patternLookup {
			paths = append(paths, p)
			continue
		}

		// the pattern is a dir containing `/...`, walk the dir recursively and
		// look for directories containing at least one .gno file and match pattern.
		visited := map[string]bool{} // used to run the builder only once per folder.
		err = filepath.WalkDir(dirToSearch, func(curpath string, f fs.DirEntry, err error) error {
			if err != nil {
				return fmt.Errorf("%s: walk dir: %w", dirToSearch, err)
			}
			// Skip directories and non ".gno" files.
			if f.IsDir() || !IsGnoFile(f) {
				return nil
			}

			parentDir := filepath.Dir(curpath)
			if _, found := visited[parentDir]; found {
				return nil
			}

			visited[parentDir] = true
			if match(parentDir) {
				paths = append(paths, parentDir)
			}

			return nil
		})
		if err != nil {
			return nil, err
		}
	}
	return paths, nil
}

// matchPattern(pattern)(name) reports whether
// name matches pattern.  Pattern is a limited glob
// pattern in which '...' means 'any string' and there
// is no other special syntax.
// Simplified version of go source's matchPatternInternal
// (see $GOROOT/src/cmd/internal/pkgpattern)
func matchPattern(pattern string) func(name string) bool {
	re := regexp.QuoteMeta(pattern)
	re = strings.Replace(re, `\.\.\.`, `.*`, -1)
	// Special case: foo/... matches foo too.
	if strings.HasSuffix(re, `/.*`) {
		re = re[:len(re)-len(`/.*`)] + `(/.*)?`
	}
	reg := regexp.MustCompile(`^` + re + `$`)
	return func(name string) bool {
		return reg.MatchString(name)
	}
}
