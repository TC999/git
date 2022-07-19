package patchwork

import (
	"bytes"
	"context"
	"fmt"
	"os"
	"path/filepath"
	"strings"
	"time"
)

type TaskApplyTopic struct {
	next     Scheduler
	nextName string
}

func (t *TaskApplyTopic) Do(o *Options, taskContext *TaskContext) error {
	if err := t.amPatches(o, taskContext); err != nil {
		return err
	}

	if t.next != nil {
		return t.next.Do(o, taskContext)
	}

	return nil
}

func (t *TaskApplyTopic) Next(scheduler Scheduler, name string) error {
	if scheduler == nil {
		return fmt.Errorf("the scheduler named %s is nil", name)
	}

	t.next = scheduler
	t.nextName = name
	return nil
}

func (t *TaskApplyTopic) amPatches(o *Options, taskContext *TaskContext) error {
	var (
		patchFolder = filepath.Join(o.CurrentPath, "patches")
	)

	if len(o.PatchFolder) > 0 {
		patchFolder = o.PatchFolder
	}

	if _, err := os.Stat(patchFolder); err != nil {
		return fmt.Errorf("ERROR: the patch '%s' not exist", patchFolder)
	}

	seriesFile := filepath.Join(patchFolder, _seriesFile)

	series, err := SeriesParse(seriesFile)
	if err != nil {
		return err
	}

	// Check apply to is or not clean in index
	if err = CheckWorkTreeClean(o.ApplyTo); err != nil {
		return err
	}

	// Checkout branch to git tag on applyTo
	if err = CheckoutBranch(o.ApplyTo, o.GitVersion); err != nil {
		return err
	}

	// Reset current branch to GitTargetVersion
	// NOTES: It must after CheckoutBranch method
	fmt.Printf("Reminding: will reset current branch to %s\n", o.GitVersion)
	if err = ResetCurrentBranch(o.ApplyTo, o.GitVersion); err != nil {
		return err
	}

	fmt.Printf("Will applying to '%0.70s'...\n", o.ApplyTo)
	defer fmt.Printf("All patches apply successfully\n\n")

	for _, s := range series {
		tmpPatchPath := filepath.Join(patchFolder, s.PatchName)

		// If not '.patch' file will ignore
		if !strings.HasSuffix(tmpPatchPath, ".patch") {
			continue
		}

		// Start apply patch
		if err = t.amPatch(o.ApplyTo, tmpPatchPath); err != nil {
			return err
		}
	}

	return nil
}

func (t *TaskApplyTopic) amPatch(repoPath, patchFile string) error {
	var (
		stdout bytes.Buffer
		stderr bytes.Buffer
	)

	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()

	fmt.Printf("Appling %0.70s...", filepath.Base(patchFile))

	cmd, err := NewCommand(ctx, repoPath, nil, nil, &stdout, &stderr,
		"git", "am", "-3", patchFile)
	if err != nil {
		return fmt.Errorf("apply patch failed, current patch: %s, err: %v", patchFile, err)
	}

	if err = cmd.Wait(); err != nil {
		defer func() {
			if err := t.amAbort(repoPath); err != nil {
				fmt.Println("cannot abort apply, you need to abort manually, err: ", err.Error())
			}
		}()

		return fmt.Errorf("apply patch failed, current patch: %s, stderr: %s, err: %v", patchFile, stderr.String(), err)
	}

	fmt.Printf("\tdone\n")
	return nil
}

func (t *TaskApplyTopic) copyFilesToFolder(srcFolder, dstFolder string) ([]string, error) {
	var res []string
	srdDirEntities, err := os.ReadDir(srcFolder)
	if err != nil {
		return nil, err
	}

	for _, entity := range srdDirEntities {
		if entity.IsDir() {
			continue
		}

		filePath := filepath.Join(srcFolder, entity.Name())
		dstFilePath := filepath.Join(dstFolder, entity.Name())
		if err := CopyFile(filePath, dstFilePath); err != nil {
			return nil, err
		}

		res = append(res, dstFilePath)
	}

	return res, nil
}

// When applying failed, then need abort.
// if not do this, it will be failed on the next time.
func (t *TaskApplyTopic) amAbort(repoPath string) error {
	var stderr bytes.Buffer
	ctx, cancel := context.WithTimeout(context.Background(), time.Second*10)
	defer cancel()

	cmd, err := NewCommand(ctx, repoPath, nil, nil, nil, &stderr,
		"git", "am", "--abort")
	if err != nil {
		return fmt.Errorf("abort apply failed, err: %v", err)
	}

	if err = cmd.Wait(); err != nil {
		return fmt.Errorf("abort apply failed, stderr: %s, err: %v", stderr.String(), err)
	}

	return nil
}
