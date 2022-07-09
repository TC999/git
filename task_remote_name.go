package agit_release

import (
	"fmt"
)

type TaskRemoteName struct {
	next     Scheduler
	nextName string
}

func (r *TaskRemoteName) Do(o *Options, taskContext *TaskContext) error {
	var err error

	if len(o.RemoteName) == 0 {
		o.RemoteName, err = GetCurrentRemoteName(o.CurrentPath)
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
