package agit_release

import (
	"bytes"
	"context"
	"fmt"
	"os"
	"path/filepath"
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

	de, err := os.ReadDir(currentPatchFolder)
	if err != nil {
		return err
	}

	// Checkout branch
	if err = CheckoutBranch(o.CurrentPath, o.ReleaseBranch); err != nil {
		return err
	}

	for _, d := range de {
		if d.IsDir() {
			continue
		}

		filePath := filepath.Join(currentPatchFolder, d.Name())

		// Start apply patch
		if err = t.amPatch(o, filePath); err != nil {
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
		"git", "am", patchFile)
	if err != nil {
		return fmt.Errorf("apply patch failed, current patch: %s, err: %v", patchFile, err)
	}

	if err = cmd.Wait(); err != nil {
		return fmt.Errorf("apply patch failed, current patch: %s, stderr: %s, err: %v", patchFile, stderr.String(), err)
	}

	fmt.Printf("\tdone\n")
	return nil
}
