package agit_release

import (
	"bufio"
	"bytes"
	"context"
	"fmt"
	"os"
	"path"
	"strings"
	"time"

	"golang.aliyun-inc.com/agit/agit-release/cmd"
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
	// Remote branch
	_branchRemoteType = iota + 1

	// Local branch
	_branchLocalType
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

	topics              []*Topic
	localTopicBranches  map[string]*Branch
	remoteTopicBranches map[string]*Branch
}

func (a *AGitTopicScheduler) ReadLocalTopicBranch(o *cmd.Options) error {
	var (
		stdout bytes.Buffer
		stderr bytes.Buffer
	)

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

func (a *AGitTopicScheduler) ReadRemoteTopicBranch(o *cmd.Options) error {
	var (
		stdout bytes.Buffer
		stderr bytes.Buffer
	)

	if a.remoteTopicBranches == nil {
		a.remoteTopicBranches = make(map[string]*Branch)
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

		// Remove refs/heads/
		branchName = strings.Replace(branchName,
			fmt.Sprintf("%s%s/", "refs/remotes/", o.RemoteName), "", 1)

		noNumberBranchName := TrimTopicPrefixNumber(branchName)

		if _, ok := a.remoteTopicBranches[noNumberBranchName]; ok {
			return fmt.Errorf("the topic: %s already exist, please check it again", branchName)
		}

		a.remoteTopicBranches[noNumberBranchName] = &Branch{
			BranchName: branchName,
			Reference:  reference,
		}
	}

	return nil
}

// GetTopics about to depend, just support one depend topic
func (a *AGitTopicScheduler) GetTopics(o *cmd.Options) error {
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
		a.ReadLocalTopicBranch(o)
	}

	// Load the remote branches
	if len(a.remoteTopicBranches) <= 0 {
		a.ReadRemoteTopicBranch(o)
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

			noNumberTopicBranch := TrimTopicPrefixNumber(topicName)
			noNumberDependBranch := TrimTopicPrefixNumber(depend)

			if v, ok := a.localTopicBranches[noNumberTopicBranch]; ok && !o.UseRemote {
				tmpBranchType = 1 << 0
				tmpBranch = v
			} else if v, ok = a.remoteTopicBranches[noNumberTopicBranch]; ok {
				tmpBranchType = 1 << 1
				tmpBranch = v
			} else {
				return fmt.Errorf("the topic: %s not exist in repo, please check it again", topicName)
			}

			if len(noNumberTopicBranch) > 0 {
				if v, ok := tmpCache[noNumberDependBranch]; ok {
					tmpDependIndex = v
				}

				if (len(noNumberDependBranch) > 0 && tmpDependIndex == -1) ||
					tmpDependIndex > index {

					return fmt.Errorf("please check topic: %s and the depend: %s, "+
						"the depend must before itself", topicName, depend)
				}
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
