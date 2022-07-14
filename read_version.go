package patchwork

import (
	"bytes"
	"fmt"
	"os"
	"path"
)

const (
	_gitVersion  = "GIT-VERSION"
	_agitVersion = "PATCH-VERSION"
)

type AGitVersion struct {
	next     Scheduler
	nextName string
}

func (a *AGitVersion) Do(o *Options, taskContext *TaskContext) error {
	if o.GitVersion != "" && o.AGitVersion != "" {
		return nil
	}

	fmt.Println("Reminding: will get git and agit version from current path files")

	gitVersionPath := path.Join(o.CurrentPath, _gitVersion)
	agitVersionPath := path.Join(o.CurrentPath, _agitVersion)

	if err := CheckFileExist(gitVersionPath, agitVersionPath); err != nil {
		return err
	}

	gitVersion, err := os.ReadFile(gitVersionPath)
	if err != nil {
		return fmt.Errorf("read git version failed, err: %v", err)
	}

	agitVersion, err := os.ReadFile(agitVersionPath)
	if err != nil {
		return fmt.Errorf("read agit verison failed, err: %v", err)
	}

	gitVersion = bytes.TrimSpace(gitVersion)
	agitVersion = bytes.TrimSpace(agitVersion)

	if len(gitVersion) <= 0 {
		return fmt.Errorf("git version is empty")
	}

	if len(agitVersion) <= 0 {
		return fmt.Errorf("agit version is empty")
	}

	o.GitVersion = string(gitVersion)
	o.AGitVersion = string(agitVersion)

	if a.next != nil {
		return a.next.Do(o, taskContext)
	}

	return nil
}

func (a *AGitVersion) Next(scheduler Scheduler, name string) error {
	if scheduler == nil {
		return fmt.Errorf("the %s is nil", name)
	}

	a.next = scheduler
	a.nextName = name
	return nil
}
