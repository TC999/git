package agit_release

import (
	"fmt"
	"os"
)

// CheckFileExist will check the paths exist, if one not exist,
// then function will break and return error.
func CheckFileExist(paths ...string) error {
	for _, path := range paths {
		if _, err := os.Stat(path); err != nil {
			return fmt.Errorf("the file %s not exist", path)
		}
	}

	return nil
}
