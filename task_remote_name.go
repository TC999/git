package agit_release

import (
	"bytes"
	"context"
	"fmt"
	"strings"
	"time"
)

type TaskRemoteName struct {
	next     Scheduler
	nextName string
}

func (r *TaskRemoteName) Do(o *Options, taskContext *TaskContext) error {
	var err error

	if len(o.RemoteName) == 0 {
		o.RemoteName, err = r.getCurrentRemoteName(o)
		if err != nil {
			return err
		}

		fmt.Printf("Remind: Remote name not provide, will be use '%s'\n", o.RemoteName)
	}

	if r.next != nil {
		return r.next.Do(o, taskContext)
	}

	return nil
}

func (r *TaskRemoteName) Next(scheduler Scheduler, name string) error {
	if scheduler == nil {
		return fmt.Errorf("the scheduler named %s is nil", name)
	}

	r.next = scheduler
	r.nextName = name
	return nil
}

// getCurrentRemoteName get current remote name from current branch
func (r *TaskRemoteName) getCurrentRemoteName(o *Options) (string, error) {
	var (
		stdout bytes.Buffer
		stderr bytes.Buffer
	)

	ctx, cancel := context.WithTimeout(context.Background(), time.Second*10)
	defer cancel()

	cmd, err := NewCommand(ctx, o.CurrentPath, nil, nil, &stdout, &stderr,
		"/bin/sh", "-c", "git config branch.$(git rev-parse --abbrev-ref HEAD).remote")
	if err != nil {
		return "", fmt.Errorf("get current branch remote name failed, err: %v", err)
	}

	if err = cmd.Wait(); err != nil {
		return "", fmt.Errorf("get current branch remote name failed, stderr: %s, err: %v", stderr.String(), err)
	}

	return strings.TrimSpace(stdout.String()), nil
}
