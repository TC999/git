package agit_release

import (
	"context"
	"fmt"
	"io"
	"os"
	"os/exec"
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

// NewCommand will return space-command for advantage use,
// You must get stdin, stdout and stderr before spaceCommand.Wait(), and do not miss spaceCommand.Wait()
func NewCommand(ctx context.Context, path string, env []string, stdin io.Reader, stdout, stderr io.Writer,
	commandName string, args ...string) (Commander, error) {
	cmd := exec.Command(commandName, args...)

	if len(path) > 0 {
		cmd.Dir = path
	}

	agitCommand, err := new(ctx, cmd, stdin, stdout, stderr, env...)
	if err != nil {
		return nil, err
	}

	return agitCommand, nil
}
