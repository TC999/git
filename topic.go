package patchwork

import (
	"bufio"
	"bytes"
	"context"
	"fmt"
	"os"
	"path"
	"strings"
	"time"
)

const (
	_topicName  = "topic.txt"
	_packedFile = "packed-refs"
)

const (
	_localTopicReference  = "refs/heads/topic"
	_remoteTopicReference = "refs/remotes/"
	_gitConfigPath        = ".git/config"
)

const (
	// Local branch
	_branchLocalType = iota + 1

	// Remote branch
	_branchRemoteType
)

type topicReader func() error

type Branch struct {
	BranchName string
	Reference  string
}

type Topic struct {
	TopicName   string
	DependIndex int

	BranchType int
	GitBranch  *Branch
}

type AGitTopicScheduler struct {
	next     Scheduler
	nextName string

	topics []*Topic

	// It is used to check local and remote, internal field
	preTopics map[string]struct{}

	localTopicBranches  map[string]*Branch
	remoteTopicBranches map[string]*Branch
}

// preReadTopicFiles this method will pre-read topic.txt, it just used for ignore the remote
// and local not contains topics in topic.txt
func (a *AGitTopicScheduler) preReadTopicFiles(o *Options) error {
	res := make(map[string]struct{})
	topicFilePath := path.Join(o.CurrentPath, _topicName)
	contents, err := os.ReadFile(topicFilePath)
	if err != nil {
		return fmt.Errorf("topic.txt file not exist")
	}

	scanner := bufio.NewScanner(bytes.NewReader(contents))
	for scanner.Scan() {
		tmpTopic := strings.TrimSpace(scanner.Text())

		// Current line is code comment, just ignore it
		if strings.HasPrefix(tmpTopic, "#") {
			continue
		}

		tmpArray := strings.Split(tmpTopic, ":")
		if len(tmpArray) == 0 {
			continue
		}

		tmpTopic = TrimTopicPrefixNumber(tmpArray[0])

		if _, ok := res[tmpTopic]; ok {
			return fmt.Errorf("the topic '%s' exists multiple times, please check it again", tmpTopic)
		}

		res[tmpTopic] = struct{}{}
	}

	a.preTopics = res
	return nil
}

func (a *AGitTopicScheduler) ReadLocalTopicBranch(o *Options) error {
	var (
		stdout bytes.Buffer
		stderr bytes.Buffer
	)

	if a.preTopics == nil {
		if err := a.preReadTopicFiles(o); err != nil {
			return err
		}
	}

	if a.localTopicBranches == nil {
		a.localTopicBranches = make(map[string]*Branch)
	}

	ctx, cancel := context.WithTimeout(context.Background(), 15*time.Second)
	defer cancel()

	cmd, err := NewCommand(ctx, o.CurrentPath, nil, nil, &stdout, &stderr,
		"git", "for-each-ref", "--format=%(objectname):%(refname)", _localTopicReference)
	if err != nil {
		return err
	}

	if err = cmd.Wait(); err != nil {
		return err
	}

	scanner := bufio.NewScanner(bytes.NewReader(stdout.Bytes()))
	for scanner.Scan() {
		line := scanner.Text()
		lineSplit := strings.Split(line, ":")
		if len(lineSplit) != 2 {
			panic("the local reference invalid")
		}

		reference := strings.TrimSpace(lineSplit[0])
		branchName := strings.TrimSpace(lineSplit[1])

		// Remove refs/heads/
		branchName = strings.Replace(branchName, "refs/heads/", "", 1)

		noNumberBranchName := TrimTopicPrefixNumber(branchName)

		// If topic.txt doesn't contain this local branch, then will skip.
		if _, ok := a.preTopics[noNumberBranchName]; !ok {
			continue
		}

		if _, ok := a.localTopicBranches[noNumberBranchName]; ok {
			return fmt.Errorf("the topic: %s already exist, please check it again", branchName)
		}

		a.localTopicBranches[noNumberBranchName] = &Branch{
			BranchName: branchName,
			Reference:  reference,
		}
	}

	return nil
}

func (a *AGitTopicScheduler) ReadRemoteTopicBranch(o *Options) error {
	var (
		stdout bytes.Buffer
		stderr bytes.Buffer
	)

	if a.remoteTopicBranches == nil {
		a.remoteTopicBranches = make(map[string]*Branch)
	}

	if a.preTopics == nil {
		if err := a.preReadTopicFiles(o); err != nil {
			return err
		}
	}

	ctx, cancel := context.WithTimeout(context.Background(), 15*time.Second)
	defer cancel()

	cmd, err := NewCommand(ctx, o.CurrentPath, nil, nil, &stdout, &stderr,
		"git", "for-each-ref", "--format=%(objectname):%(refname)",
		fmt.Sprintf("%s%s/topic", _remoteTopicReference, o.RemoteName))
	if err != nil {
		return err
	}

	if err = cmd.Wait(); err != nil {
		return err
	}

	scanner := bufio.NewScanner(bytes.NewReader(stdout.Bytes()))
	for scanner.Scan() {
		line := scanner.Text()
		lineSplit := strings.Split(line, ":")
		if len(lineSplit) != 2 {
			panic("the local reference invalid")
		}

		reference := strings.TrimSpace(lineSplit[0])
		branchName := strings.TrimSpace(lineSplit[1])

		// Remove refs/remotes/${remote}
		branchName = strings.Replace(branchName,
			fmt.Sprintf("%s%s/", "refs/remotes/", o.RemoteName), "", 1)

		noNumberBranchName := TrimTopicPrefixNumber(branchName)

		// If topic.txt doesn't contain this remote branch, then will skip.
		if _, ok := a.preTopics[noNumberBranchName]; !ok {
			continue
		}

		if v, ok := a.remoteTopicBranches[noNumberBranchName]; ok {
			return fmt.Errorf("the topic: %s already exist, please check remote branch '%s' and '%s'\n",
				noNumberBranchName, v.BranchName, branchName)
		}

		a.remoteTopicBranches[noNumberBranchName] = &Branch{
			BranchName: fmt.Sprintf("%s/%s", o.RemoteName, branchName),
			Reference:  reference,
		}
	}

	return nil
}

// GetTopics about to depend, just support one depend topic
func (a *AGitTopicScheduler) GetTopics(o *Options) error {
	var (
		// Just used to record the index for depends
		tmpCache = make(map[string]int)
		index    int
	)

	topicFilePath := path.Join(o.CurrentPath, _topicName)

	if err := CheckFileExist(topicFilePath); err != nil {
		return err
	}

	// Load the local branches
	if len(a.localTopicBranches) <= 0 {
		if err := a.ReadLocalTopicBranch(o); err != nil {
			return err
		}
	}

	// Load the remote branches
	if len(a.remoteTopicBranches) <= 0 {
		if err := a.ReadRemoteTopicBranch(o); err != nil {
			return err
		}
	}

	if contents, err := os.ReadFile(topicFilePath); err == nil {
		scanner := bufio.NewScanner(bytes.NewReader(contents))
		for scanner.Scan() {
			var (
				topicName      string
				depend         string
				tmpBranchType  int
				tmpBranch      *Branch
				tmpDependIndex = -1
			)

			line := strings.TrimSpace(scanner.Text())

			// Current line is code comment, just ignore it
			if strings.HasPrefix(line, "#") {
				continue
			}

			splitLine := strings.Split(line, ":")
			if len(splitLine) >= 1 {
				topicName = strings.TrimSpace(splitLine[0])
			}

			if len(splitLine) >= 2 {
				depend = strings.TrimSpace(splitLine[1])
			}

			noNumberDependBranch := TrimTopicPrefixNumber(depend)

			tmpBranch, tmpBranchType, err = a.choiceBranch(o, topicName, a.localTopicBranches, a.remoteTopicBranches)
			if err != nil {
				return err
			}

			if len(topicName) > 0 {
				if v, ok := tmpCache[noNumberDependBranch]; ok {
					tmpDependIndex = v
				}

				// Do not check the depend invalid, the other task will sort the depends
				//if (len(noNumberDependBranch) > 0 && tmpDependIndex == -1) ||
				//	tmpDependIndex > index {
				//
				//	return fmt.Errorf("please check topic: %s and the depend: %s, "+
				//		"the depend must before itself", topicName, depend)
				//}
			}

			a.topics = append(a.topics,
				&Topic{
					TopicName:   topicName,
					DependIndex: tmpDependIndex,
					BranchType:  tmpBranchType,
					GitBranch:   tmpBranch,
				})

			tmpCache[topicName] = index

			index++
		}
	}

	return nil
}

func (a *AGitTopicScheduler) choiceBranch(o *Options, topicName string, localTopicBranches,
	remoteTopicBranches map[string]*Branch) (_ *Branch, branchType int, _ error) {
	var (
		tmpLocalBranch  *Branch
		tmpRemoteBranch *Branch
	)

	noNumberTopicBranch := TrimTopicPrefixNumber(topicName)
	tmpLocalBranch = localTopicBranches[noNumberTopicBranch]
	tmpRemoteBranch = remoteTopicBranches[noNumberTopicBranch]

	if tmpLocalBranch == nil && tmpRemoteBranch == nil {
		return nil, 0, fmt.Errorf("the topic '%s' does not exit in local and remote", topicName)
	}

	switch o.BranchMode {
	case UseLocalMode:
		if tmpLocalBranch != nil {
			return tmpLocalBranch, _branchLocalType, nil
		}

		// If local is nil, then will user remote
		return tmpRemoteBranch, _branchRemoteType, nil
	case UseRemoteMode:
		if tmpRemoteBranch == nil {
			return nil, 0, fmt.Errorf("the topic '%s' does not exit in remote", topicName)
		}

		return tmpRemoteBranch, _branchRemoteType, nil
	case DefaultBranchMode:
		if tmpLocalBranch != nil && tmpRemoteBranch != nil &&
			tmpLocalBranch.Reference != tmpRemoteBranch.Reference {
			return nil, 0, fmt.Errorf("the topic '%s' local and remote are inconsistent,"+
				" plese use '--use-local' or '--use-remote'", topicName)
		}

		if tmpLocalBranch == nil || tmpRemoteBranch == nil {
			// tmpLocalBranch or tmpRemoteBranch is nil
			return nil, 0, fmt.Errorf("the topic '%s' local and remote are inconsistent,"+
				" please use '--use-local' or '--use-remote'", topicName)
		}

		return tmpLocalBranch, _branchLocalType, nil
	}

	return nil, 0, fmt.Errorf("BUG: branch mode invalid")
}
