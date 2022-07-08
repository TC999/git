package agit_release

import (
	"fmt"
	"sort"
)

type TaskTopicSort struct {
	next     Scheduler
	nextName string
}

func (t *TaskTopicSort) Do(o *Options, taskContext *TaskContext) error {
	if err := t.sortDepend(taskContext); err != nil {
		return err
	}

	if t.next != nil {
		return t.next.Do(o, taskContext)
	}

	return nil
}

func (t *TaskTopicSort) Next(scheduler Scheduler, name string) error {
	if scheduler == nil {
		return fmt.Errorf("the scheduler named %s is nil", name)
	}

	t.next = scheduler
	t.nextName = name
	return nil
}

type dependDesc struct {
	CurrentIndex int
	DependIndex  int
	Topic        *Topic
	DependTopic  *Topic
}

// sortDepend will try to verify and re-sort the order
func (t *TaskTopicSort) sortDepend(taskContext *TaskContext) error {
	topicCount := len(taskContext.topics)
	var (
		// It will record the not have depended on topic
		noDependTopics = make([]*Topic, 0, topicCount)

		// It will record exist depended on topic
		dependTopicDesc = make([]*dependDesc, 0, topicCount)

		// It will record sorted topics
		sortedTopics = make([]*Topic, 0, topicCount)

		// It will record the new order topic index which will be
		// used to update 'depend on' index
		newOrderMap = make(map[string]int)
	)

	for index, topic := range taskContext.topics {
		if topic.DependIndex >= 0 {
			dependTopicDesc = append(dependTopicDesc, &dependDesc{
				CurrentIndex: index,
				DependIndex:  topic.DependIndex,
				Topic:        topic,
				DependTopic:  taskContext.topics[topic.DependIndex],
			})
			continue
		}

		noDependTopics = append(noDependTopics, topic)
		newOrderMap[topic.GitBranch.BranchName] = len(noDependTopics) - 1
	}

	sortedDependTopics, err := sortDependTopics(dependTopicDesc)
	if err != nil {
		return err
	}

	// Add no depend
	sortedTopics = append(sortedTopics, noDependTopics...)

	// Add sorted depend
	for _, sorted := range sortedDependTopics {
		newOrderMap[sorted.Topic.GitBranch.BranchName] = len(sortedTopics)

		// Reset the dependIndex
		if v, ok := newOrderMap[sorted.DependTopic.GitBranch.BranchName]; ok {
			sorted.Topic.DependIndex = v
		}

		sortedTopics = append(sortedTopics, sorted.Topic)
	}

	// Update the context
	taskContext.topics = sortedTopics
	return nil
}

func sortDependTopics(dependTopicDesc []*dependDesc) ([]*dependDesc, error) {
	var (
		// dependLink []*dependDesc
		allLinks [][]*dependDesc
		result   []*dependDesc
	)

	if len(dependTopicDesc) == 0 {
		return dependTopicDesc, nil
	}

	sort.Slice(dependTopicDesc, func(i, j int) bool {
		return dependTopicDesc[i].CurrentIndex < dependTopicDesc[j].CurrentIndex &&
			dependTopicDesc[i].DependIndex < dependTopicDesc[j].DependIndex
	})

	continueSeek := true
	for len(dependTopicDesc) > 0 {
		var dependLink []*dependDesc
		dependLink = append(dependLink, &dependDesc{
			CurrentIndex: dependTopicDesc[0].CurrentIndex,
			DependIndex:  dependTopicDesc[0].DependIndex,
			Topic:        dependTopicDesc[0].Topic,
			DependTopic:  dependTopicDesc[0].DependTopic,
		})

		dependTopicDesc = append(dependTopicDesc[:0], dependTopicDesc[0+1:]...)

		for continueSeek && len(dependTopicDesc) > 0 {
			for i, topicDesc := range dependTopicDesc {
				if topicDesc.DependIndex == dependLink[len(dependLink)-1].CurrentIndex {
					dependLink = append(dependLink, topicDesc)
					dependTopicDesc = append(dependTopicDesc[:i], dependTopicDesc[i+1:]...)
					continueSeek = true
					break
				}

				continueSeek = false
			}
		}

		allLinks = append(allLinks, dependLink)
	}

	for _, links := range allLinks {
		if len(links) > 0 {
			if links[0].DependIndex == links[len(links)-1].CurrentIndex {
				// circular reference
				// TODO print links to user
				return nil, fmt.Errorf("circular reference")
			}
		}

		result = append(result, links...)
	}

	// TODO 由于顺序变更，depend index 是错的，需要校正
	return result, nil
}
