package patchwork

import (
	"fmt"
)

func (a *AGitTopicScheduler) Do(o *Options, taskContext *TaskContext) error {
	if err := a.GetTopics(o); err != nil {
		return err
	}

	taskContext.topics = a.topics
	taskContext.localTopicBranches = a.localTopicBranches
	taskContext.remoteTopicBranches = a.remoteTopicBranches

	if a.next != nil {
		return a.next.Do(o, taskContext)
	}

	return nil
}

func (a *AGitTopicScheduler) Next(scheduler Scheduler, name string) error {
	if scheduler != nil {
		a.next = scheduler
		a.nextName = name
		return nil
	}

	return fmt.Errorf("scheduler %s cannot be nil", name)
}
