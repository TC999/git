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
	currentPatchFolder := filepath.Join(o.CurrentPath, "patches", "t")
	currentBranch, err := GetCurrentBranchName(o.CurrentPath)
	if err != nil {
		return err
	}

	tmpFolder, err := os.MkdirTemp("", "patchwork-*")
	if err != nil {
		return err
	}
	defer os.RemoveAll(tmpFolder)

	fmt.Printf("Will applying to '%s' branch...\n", o.ReleaseBranch)

	// Checkout branch
	if err = CheckoutBranch(o.CurrentPath, o.ReleaseBranch); err != nil {
		return err
	}

	// Reset current branch to GitTargetVersion
	// NOTES: It must after CheckoutBranch method
	if o.ForceResetReleaseBranch {
		fmt.Printf("Reminding: will reset current branch to %s\n", o.GitVersion)
		if err = ResetCurrentBranch(o.CurrentPath, o.GitVersion); err != nil {
			return err
		}
	}

	// When finished, checkout back
	defer func() {
		if err = CheckoutBranch(o.CurrentPath, currentBranch); err != nil {
			fmt.Println("cannot checkout back: ", err.Error())
		}
	}()

	patchFiles, err := t.copyFilesToFolder(currentPatchFolder, tmpFolder)
	if err != nil {
		return err
	}

	for _, patchFile := range patchFiles {
		// If not '.patch' file will ignore
		if !strings.HasSuffix(patchFile, ".patch") {
			continue
		}

		// Start apply patch
		if err = t.amPatch(o, patchFile); err != nil {
			return err
		}
	}

	return nil
}

func (t *TaskApplyTopic) amPatch(o *Options, patchFile string) error {
	var (
		stdout bytes.Buffer
		stderr bytes.Buffer
	)

	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()

	fmt.Printf("Appling %0.70s...", filepath.Base(patchFile))

	cmd, err := NewCommand(ctx, o.CurrentPath, nil, nil, &stdout, &stderr,
		"git", "am", "-3", patchFile)
	if err != nil {
		return fmt.Errorf("apply patch failed, current patch: %s, err: %v", patchFile, err)
	}

	if err = cmd.Wait(); err != nil {
		defer func() {
			if err := t.amAbort(o); err != nil {
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
func (t *TaskApplyTopic) amAbort(o *Options) error {
	var stderr bytes.Buffer
	ctx, cancel := context.WithTimeout(context.Background(), time.Second*10)
	defer cancel()

	cmd, err := NewCommand(ctx, o.CurrentPath, nil, nil, nil, &stderr,
		"git", "am", "--abort")
	if err != nil {
		return fmt.Errorf("abort apply failed, err: %v", err)
	}

	if err = cmd.Wait(); err != nil {
		return fmt.Errorf("abort apply failed, stderr: %s, err: %v", stderr.String(), err)
	}

	return nil
}
