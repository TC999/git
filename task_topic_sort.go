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
	var noDependTopics []*dependDesc

	dependTopics := make([]*Topic, 0, topicCount)

	for index, topic := range taskContext.topics {
		if topic.DependIndex >= 0 {
			dependTopics = append(dependTopics, topic)
			continue
		}

		noDependTopics = append(noDependTopics, &dependDesc{
			CurrentIndex: index,
			DependIndex:  topic.DependIndex,
			Topic:        topic,
			DependTopic:  taskContext.topics[topic.DependIndex],
		})
	}

	sort.Slice(dependTopics, func(i, j int) bool {
		return dependTopics[i].DependIndex < dependTopics[j].DependIndex
	})

	// TODO not implement

	return nil
}

func sortDependTopics(dependTopics []*dependDesc) ([]*dependDesc, error) {
	var (
		//dependLink []*dependDesc
		allLinks [][]*dependDesc
		result   []*dependDesc
	)

	if len(dependTopics) == 0 {
		return dependTopics, nil
	}

	continueSeek := true
	for len(dependTopics) > 0 {
		var dependLink []*dependDesc
		dependLink = append(dependLink, &dependDesc{
			CurrentIndex: dependTopics[0].CurrentIndex,
			DependIndex:  dependTopics[0].DependIndex,
			Topic:        dependTopics[0].Topic,
			DependTopic:  dependTopics[0].DependTopic,
		})

		dependTopics = append(dependTopics[:0], dependTopics[0+1:]...)

		for continueSeek && len(dependTopics) > 0 {
			for i, topicDesc := range dependTopics {
				if topicDesc.DependIndex == dependLink[len(dependLink)-1].CurrentIndex {
					dependLink = append(dependLink, topicDesc)
					dependTopics = append(dependTopics[:i], dependTopics[i+1:]...)
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
