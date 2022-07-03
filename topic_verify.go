package agit_release

import (
	"bytes"
	"context"
	"fmt"
	"strings"
	"time"
)

type TopicVerify struct {
	next     Scheduler
	nextName string
}

func (t *TopicVerify) Do(o *Options, taskContext *TaskContext) error {
	if err := verify(o, taskContext); err != nil {
		return err
	}

	if t.next != nil {
		t.next.Do(o, taskContext)
	}

	return nil
}

func (t *TopicVerify) Next(scheduler Scheduler, name string) error {
	if scheduler == nil {
		return fmt.Errorf("the scedule named %s is nil", name)
	}

	t.nextName = name
	t.next = scheduler

	return nil
}

func verify(o *Options, taskContext *TaskContext) error {
	for _, topic := range taskContext.topics {
		localBranch := taskContext.localTopicBranches[topic.TopicName]
		remoteBranch := taskContext.remoteTopicBranches[topic.TopicName]
		if err := verifyLocalBranchIsOld(o, localBranch, remoteBranch); err != nil {
			return err
		}

		if err := verifyBranchIsRebasedGitVersion(o, topic.GitBranch); err != nil {
			return err
		}
	}

	return nil
}

func verifyBranchIsRebasedGitVersion(o *Options, branch *Branch) error {
	var (
		stdout bytes.Buffer
		stderr bytes.Buffer
	)

	ctx, cancel := context.WithTimeout(context.Background(), time.Second*10)
	defer cancel()

	if branch != nil {
		cmd, err := NewCommand(ctx, o.CurrentPath, nil, nil, &stdout, &stderr,
			"git", "log", "--oneline", fmt.Sprintf("%s..%s", branch.BranchName, o.GitVersion))
		if err != nil {
			return fmt.Errorf("verify rebased git version failed, err: %v", err)
		}

		if err = cmd.Wait(); err != nil {
			return fmt.Errorf("verify rebased git version failed, err: %v", err)
		}

		if len(strings.TrimSpace(stdout.String())) > 0 {
			return fmt.Errorf("the branch %s not rebase to %s", branch.BranchName, o.GitVersion)
		}
	}

	return nil
}

func verifyLocalBranchIsOld(o *Options, localBranch *Branch, remoteBranch *Branch) error {
	var (
		stdout bytes.Buffer
		stderr bytes.Buffer
	)

	if localBranch == nil || remoteBranch == nil {
		// if local or remote branch not exist, then will not do this check
		return nil
	}

	ctx, cancel := context.WithTimeout(context.Background(), time.Second*10)
	defer cancel()

	cmd, err := NewCommand(ctx, o.CurrentPath, nil, nil, &stdout, &stderr,
		"git", "log", "--oneline", fmt.Sprintf("%s..%s", localBranch.BranchName, remoteBranch.BranchName))
	if err != nil {
		return fmt.Errorf("verify branch is old failed, err: %v", err)
	}

	if err = cmd.Wait(); err != nil {
		return fmt.Errorf("verify branch is old failed, err: %v", err)
	}

	if len(strings.TrimSpace(stdout.String())) != 0 {
		return fmt.Errorf("your branch: '%s' is behind '%s', you need fetch it first", localBranch.BranchName, remoteBranch.BranchName)
	}

	return nil
}
