package agit_release

import (
	"context"
	"fmt"
	"io"
	"os"
	"os/exec"
	"path"
	"regexp"
	"strings"
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

// TrimTopicPrefixNumber trim the topic number
func TrimTopicPrefixNumber(topicName string) string {
	var tmpTopic = topicName
	if len(topicName) > 0 {
		if strings.HasPrefix(topicName, "topic/") {
			tmpTopic = strings.SplitN(topicName, "topic/", 2)[1]
		}

		reg := regexp.MustCompile("^[0-9]{1,6}-(\\S*)")
		matchedNameArray := reg.FindStringSubmatch(tmpTopic)

		// The index 1 is the string self
		if len(matchedNameArray) != 2 {
			return path.Join("topic/", tmpTopic)
		}

		return path.Join("topic/", reg.FindStringSubmatch(tmpTopic)[1])
	}

	return ""
}
