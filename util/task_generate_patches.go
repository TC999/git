package patchwork

import (
	"bufio"
	"bytes"
	"context"
	"fmt"
	"os"
	"path"
	"path/filepath"
	"strconv"
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

	// If the patchFolder not exit, will try to create
	if err := MkdirDirAll(patchFolder); err != nil {
		return err
	}

	isHaveFile, err := CheckFolderIsHaveFiles(patchFolder)
	if err != nil {
		return err
	}

	if isHaveFile {
		return fmt.Errorf("ERROR: the patch '%s' is not empty, please manually delete the contents",
			patchFolder)
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

			if !o.PatchNumber {
				tmpPatchPath, err = g.removeNumberFormFileName(tmpPatchPath)
				if err != nil {
					return err
				}
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

func (g *GeneratePatches) removeNumberFormFileName(patchPath string) (string, error) {
	var (
		patchFolder  = path.Dir(patchPath)
		patchName    = path.Base(patchPath)
		newPatchName = patchName
		newPatchPath = patchPath
	)

	if index := strings.Index(patchName, "-"); index > -1 {
		newPatchName = patchName[index+1:]
		newPatchPath = path.Join(patchFolder, newPatchName)

		// The patch was existed, need to rename
		// TODO: the possibility of file renaming is not very high, so the method of
		// judging whether the file name exists in a for is relatively inefficient, but
		// it is more effective for the current scene, Add a TODO here to mark the point
		// that can be optimized
		for CheckFileExist(newPatchPath) == nil {
			newPatchPath = g.renamePatch(newPatchPath)
		}

		return newPatchPath, os.Rename(patchPath, newPatchPath)
	}

	return patchPath, nil
}

func (g *GeneratePatches) renamePatch(patchPath string) string {
	patchFolder := path.Dir(patchPath)
	patchName := path.Base(patchPath)
	ext := path.Ext(patchName)
	nameWithoutExtension := patchName[:len(patchName)-len(ext)]
	underlineIndex := strings.LastIndex(nameWithoutExtension, "_")
	fileNumberStr := nameWithoutExtension[underlineIndex+1:]

	fileNumber, err := strconv.Atoi(fileNumberStr)
	if err != nil {
		// If fileNumber not a number, then append "_1" to the file
		return filepath.Join(patchFolder, fmt.Sprintf("%s_1%s", nameWithoutExtension, ext))
	}

	fileNumber++
	nameWithoutNumber := nameWithoutExtension[:underlineIndex]
	return filepath.Join(patchFolder, fmt.Sprintf("%s_%d%s", nameWithoutNumber, fileNumber, ext))
}
