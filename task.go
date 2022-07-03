package agit_release

import (
	"fmt"
)

type TaskContext struct {
	topics              []*Topic
	localTopicBranches  map[string]*Branch
	remoteTopicBranches map[string]*Branch
	testList            []string
}

type Scheduler interface {
	Do(option *Options, taskContext *TaskContext) error
	Next(scheduler Scheduler, name string) error
}

type ReleaseScheduler struct {
	next     Scheduler
	nextName string
}

func (r *ReleaseScheduler) Do(option *Options, taskContext *TaskContext) error {
	if r.next != nil {
		return r.next.Do(option, taskContext)
	}

	return fmt.Errorf("execute %s failed", r.nextName)
}

func (r *ReleaseScheduler) Next(scheduler Scheduler, name string) error {
	if scheduler == nil {
		return fmt.Errorf("the scheduler cannot be nil")
	}

	r.next = scheduler
	r.nextName = name

	return nil
}
