package patchwork

import (
	"bufio"
	"bytes"
	"context"
	"fmt"
	"os"
	"path/filepath"
	"strings"
	"time"
)

const (
	_outputFolderName = "patches/t"
	_seriesFile       = "patches/series"
)

const (
	_agitReleaseTopic = "agit-version"
	_agitDevVersion   = "agit.dev"
)

type GeneratePatches struct {
	next     Scheduler
	nextName string
}

func (g *GeneratePatches) Do(o *Options, taskContext *TaskContext) error {
	if err := g.Generate(o, taskContext); err != nil {
		return err
	}

	if g.next != nil {
		return g.next.Do(o, taskContext)
	}

	return nil
}

func (g *GeneratePatches) Next(scheduler Scheduler, name string) error {
	if scheduler == nil {
		return fmt.Errorf("the scheduler named %s is nil", name)
	}

	g.next = scheduler
	g.nextName = name
	return nil
}

func (g *GeneratePatches) Generate(o *Options, taskContext *TaskContext) error {
	var patchNumber = 1

	if len(taskContext.topics) <= 0 {
		return fmt.Errorf("the topic is empty")
	}

	ctx, cancel := context.WithTimeout(context.Background(), time.Second*10)
	defer cancel()

	if err := createPatchFolder(o); err != nil {
		return err
	}

	f, err := os.OpenFile(filepath.Join(o.CurrentPath, _seriesFile), os.O_CREATE|os.O_WRONLY|os.O_TRUNC, 0o644)
	if err != nil {
		return fmt.Errorf("write series file failed, err: %v", err)
	}
	defer f.Close()

	for _, topic := range taskContext.topics {
		var (
			stdout bytes.Buffer
			stderr bytes.Buffer

			isReplaceAgitVersion bool
		)

		if topic.TopicName == _agitReleaseTopic {
			isReplaceAgitVersion = true
		}

		fmt.Printf("Generating %0.70s...", topic.GitBranch.BranchName)

		rangeArgument := fmt.Sprintf("%s..%s", o.GitVersion, topic.GitBranch.BranchName)
		if topic.DependIndex >= 0 {
			rangeArgument = fmt.Sprintf("%s..%s",
				taskContext.topics[topic.DependIndex].GitBranch.BranchName, topic.GitBranch.BranchName)
		}

		cmd, err := NewCommand(ctx, o.CurrentPath, nil, nil, &stdout, &stderr,
			"git", "format-patch", "-o", _outputFolderName,
			fmt.Sprintf("--start-number=%04d", patchNumber), rangeArgument)
		if err != nil {
			return fmt.Errorf("generate patch failed, err: %v", err)
		}

		if err = cmd.Wait(); err != nil {
			return fmt.Errorf("generate patch failed, stderr: %s, err: %v", stderr.String(), err)
		}

		scanner := bufio.NewScanner(bytes.NewReader(stdout.Bytes()))

		for scanner.Scan() {
			tmpPatchName := scanner.Text()

			// Replace agit version
			if isReplaceAgitVersion {
				if err = setAgitVersionOnPatch(o, tmpPatchName); err != nil {
					return err
				}
			}

			// Replace patch client git version
			if err = g.ReplaceClientGitVersion(o, tmpPatchName); err != nil {
				return err
			}

			if strings.HasPrefix(tmpPatchName, "patches/") {
				tmpPatchName = strings.Replace(tmpPatchName, "patches/", "", 1)
			}

			f.WriteString(fmt.Sprintf("%s\n", tmpPatchName))
			patchNumber++
		}

		isReplaceAgitVersion = false

		fmt.Printf("\t done\n")
	}

	fmt.Printf("Successfully generate all the patches\n\n")
	return nil
}

// ReplaceClientGitVersion replace the patches last line version
func (g *GeneratePatches) ReplaceClientGitVersion(o *Options, patchName string) error {
	patchPath := filepath.Join(o.CurrentPath, patchName)
	currentVersion, err := GetCurrentGitVersion(o.CurrentPath)
	if err != nil {
		return err
	}

	if err := FindLastLineFromEndAndReplace(patchPath, currentVersion, "patchwork"); err != nil {
		return err
	}

	return nil
}

// setAgitVersionOnPatch will replace 'agit.dev' to really agit verison
func setAgitVersionOnPatch(o *Options, patchName string) error {
	patchPath := filepath.Join(o.CurrentPath, patchName)

	contents, err := os.ReadFile(patchPath)
	if err != nil {
		return err
	}

	newContents := strings.Replace(string(contents), _agitDevVersion, o.AGitVersion, -1)

	return os.WriteFile(patchPath, []byte(newContents), 0o644)
}

func createPatchFolder(o *Options) error {
	patchFolder := filepath.Join(o.CurrentPath, "patches", "t")
	_, err := os.Stat(patchFolder)
	if err == nil {
		return nil
	}

	return os.MkdirAll(patchFolder, 0o755)
}
