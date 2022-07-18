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
	_outputFolderName = "t"
	_seriesFile       = "series"
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
	var (
		patchNumber = 1
		patchFolder = filepath.Join(o.CurrentPath, "patches")
	)

	if len(taskContext.topics) <= 0 {
		return fmt.Errorf("the topic is empty")
	}

	ctx, cancel := context.WithTimeout(context.Background(), time.Second*10)
	defer cancel()

	if len(strings.TrimSpace(o.PatchFolder)) > 0 {
		patchFolder = o.PatchFolder
	}

	// If user provide '--patches', will check folder whether folder have files.
	// If have some filed, then will confirm user whether continue or cancel.
	if len(o.PatchFolder) > 0 {
		isHaveFile, err := CheckFolderIsHaveFiles(o.PatchFolder)
		if err != nil {
			return err
		}

		if isHaveFile {
			fmt.Printf("The folder: %s not empty, do you want to overwrite?", o.PatchFolder)
			confirmRes := ConsoleConfirm()
			if !confirmRes {
				return fmt.Errorf("patchwork canceled")
			}

			os.RemoveAll(patchFolder)
		}
	}

	if err := g.createPatchFolder(patchFolder, ""); err != nil {
		return err
	}

	f, err := os.OpenFile(filepath.Join(patchFolder, _seriesFile), os.O_CREATE|os.O_WRONLY|os.O_TRUNC, 0o644)
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
			"git", "format-patch", "-o", filepath.Join(patchFolder, _outputFolderName),
			fmt.Sprintf("--start-number=%04d", patchNumber), rangeArgument)
		if err != nil {
			return fmt.Errorf("generate patch failed, err: %v", err)
		}

		if err = cmd.Wait(); err != nil {
			return fmt.Errorf("generate patch failed, stderr: %s, err: %v", stderr.String(), err)
		}

		scanner := bufio.NewScanner(bytes.NewReader(stdout.Bytes()))

		for scanner.Scan() {
			tmpPatchPath := scanner.Text()

			// Replace agit version
			if isReplaceAgitVersion {
				if err = g.setAgitVersionOnPatch(o, tmpPatchPath); err != nil {
					return err
				}
			}

			// Replace patch client git version
			if err = g.ReplaceClientGitVersion(o, tmpPatchPath); err != nil {
				return err
			}

			patchName := filepath.Join(_outputFolderName, filepath.Base(tmpPatchPath))
			f.WriteString(fmt.Sprintf("%s\n", patchName))
			patchNumber++
		}

		isReplaceAgitVersion = false

		fmt.Printf("\t done\n")
	}

	fmt.Printf("Successfully generate all the patches\n\n")
	return nil
}

// ReplaceClientGitVersion replace the patches last line version
func (g *GeneratePatches) ReplaceClientGitVersion(o *Options, patchPath string) error {
	currentVersion, err := GetCurrentGitVersion(o.CurrentPath)
	if err != nil {
		return err
	}

	if err := FindLastLineFromEndAndReplace(patchPath, currentVersion, "patchwork"); err != nil {
		return err
	}

	return nil
}

// setAgitVersionOnPatch will replace 'agit.dev' to really agit version
func (g *GeneratePatches) setAgitVersionOnPatch(o *Options, patchPath string) error {
	contents, err := os.ReadFile(patchPath)
	if err != nil {
		return err
	}

	newContents := strings.Replace(string(contents), _agitDevVersion, o.AGitVersion, -1)

	return os.WriteFile(patchPath, []byte(newContents), 0o644)
}

func (g *GeneratePatches) createPatchFolder(patchPath, prefix string) error {
	tmpPatchArray := []string{patchPath}
	prefixArray := strings.Split(prefix, "/")
	tmpPatchArray = append(tmpPatchArray, prefixArray...)

	// Why have t folder? the t folder will save all the patches files.
	tmpPatchArray = append(tmpPatchArray, "t")

	patchFolder := filepath.Join(tmpPatchArray...)
	_, err := os.Stat(patchFolder)
	if err == nil {
		return nil
	}

	return os.MkdirAll(patchFolder, 0o755)
}
