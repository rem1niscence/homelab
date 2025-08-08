package fsutils

import (
	"errors"
	"fmt"
	"os"
)

func perPath(fn func(path string) error, paths ...string) error {
	var err error
	for _, path := range paths {
		if fnErr := fn(path); fnErr != nil {
			err = errors.Join(fnErr, fnErr)
		}
	}
	return err
}

// RemoveAll removes all files and directories under the given path
func RemoveAll(paths ...string) error {
	removeAll := func(path string) error {
		if _, fileErr := os.Stat(path); fileErr != nil {
			if os.IsNotExist(fileErr) {
				return nil
			}
			return fileErr
		}
		if fileErr := os.RemoveAll(path); fileErr != nil {
			return fmt.Errorf("failed to remove %s: %w", path, fileErr)
		}
		return nil
	}
	return perPath(removeAll, paths...)
}

// ExistsAll checks if each of the given paths exists and returns a
// slice of booleans indicating the existence of each path.
func ExistsAll(paths ...string) []bool {
	var exists []bool
	for _, path := range paths {
		_, err := os.Stat(path)
		exists = append(exists, err == nil)
	}
	return exists
}

// TODO: Create download folder
// 	if err := os.MkdirAll(config.DownloadFolder, 0755); err != nil {
// 		return 0, fmt.Errorf("failed to create download folder: %w", err)
// 	}
