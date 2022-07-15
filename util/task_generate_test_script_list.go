package patchwork

import (
	"bytes"
	"context"
	"fmt"
	"os"
	"path/filepath"
	"regexp"
	"strings"
	"time"
)

const (
	_testFileReg = "t/(t[0-9]{4,}-[^/]*.sh)"
)

const (
	_testScriptList = "patches/test-scripts"
)

type TaskGenerateTestScriptList struct {
	next     Scheduler
	nextName string
}

func (t *TaskGenerateTestScriptList) Do(o *Options, taskContext *TaskContext) error {
	if err := t.writeTestScriptsFile(o, taskContext); err != nil {
		return err
	}

	if t.next != nil {
		return t.next.Do(o, taskContext)
	}

	return nil
}

func (t *TaskGenerateTestScriptList) Next(scheduler Scheduler, name string) error {
	if scheduler == nil {
		return fmt.Errorf("the scheduler named '%s' is nil", name)
	}

	t.nextName = name
	t.next = scheduler
	return nil
}

func (t *TaskGenerateTestScriptList) writeTestScriptsFile(o *Options, taskContext *TaskContext) error {
	testFiles, err := t.getTestListFromTopic(o, taskContext)
	if err != nil {
		return err
	}

	testSeriesFilePath := filepath.Join(o.CurrentPath, _testScriptList)

	os.Remove(testSeriesFilePath)

	contents := strings.Join(testFiles, "\n") + "\n"

	fmt.Printf("Starting to write %s file", _testScriptList)

	f, err := os.OpenFile(testSeriesFilePath, os.O_CREATE|os.O_WRONLY|os.O_TRUNC, 0o644)
	if err != nil {
		return err
	}
	defer f.Close()
	f.WriteString(contents)

	fmt.Print("\tdone\n\n")

	return nil
}

func (t *TaskGenerateTestScriptList) getTestListFromTopic(o *Options, taskContext *TaskContext) ([]string, error) {
	var res []string
	if len(taskContext.topics) == 0 {
		return nil, fmt.Errorf("not found topic")
	}

	if len(o.GitVersion) == 0 {
		return nil, fmt.Errorf("not set --git-version")
	}

	for _, topic := range taskContext.topics {
		tmpTestFiles, err := t.getTopicTestFiles(o, topic.GitBranch.BranchName)
		if err != nil {
			return nil, err
		}

		res = append(res, tmpTestFiles...)
	}

	return res, nil
}

// getTopicTestFiles get test files from topic
// it just gets the first level on test which path start with 't/',
// such as 't/t0940-crypto-repository.sh'
func (t *TaskGenerateTestScriptList) getTopicTestFiles(o *Options, topicBranchName string) ([]string, error) {
	var (
		stdout bytes.Buffer
		stderr bytes.Buffer
		res    []string
	)

	ctx, cancel := context.WithTimeout(context.Background(), time.Second*10)
	defer cancel()

	cmd, err := NewCommand(ctx, o.CurrentPath, nil, nil, &stdout, &stderr,
		"git", "diff", "--name-only",
		fmt.Sprintf("%s..%s", o.GitVersion, topicBranchName))
	if err != nil {
		return nil, fmt.Errorf("get test files from topic: '%s' failed, err: %v", topicBranchName, err)
	}

	if err = cmd.Wait(); err != nil {
		return nil, fmt.Errorf("get test files from topic: '%s' failed, stderr: %s", topicBranchName, stderr.String())
	}

	reg := regexp.MustCompile(_testFileReg)
	for _, matched := range reg.FindAllStringSubmatch(stdout.String(), -1) {
		if len(matched) > 1 {
			res = append(res, matched[1])
		}
	}

	return res, nil
}
