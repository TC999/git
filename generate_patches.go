package agit_release

import (
	"bufio"
	"bytes"
	"context"
	"fmt"
	"os"
	"path/filepath"
	"time"
)

const (
	_outputFolderName = "patches/t"
	_seriesFile       = "patches/series"
)

type GeneratePatches struct {
	next     Scheduler
	nextName string
}

func (g *GeneratePatches) Do(o *Options, taskContext *TaskContext) error {
	if err := g.Generate(o, taskContext); err != nil {
		return err
	}

	if g.next != nil {
		return g.next.Do(o, taskContext)
	}

	return nil
}

func (g *GeneratePatches) Next(scheduler Scheduler, name string) error {
	if scheduler == nil {
		return fmt.Errorf("the scheduler named %s is nil", name)
	}

	g.next = scheduler
	g.nextName = name
	return nil
}

func (g *GeneratePatches) Generate(o *Options, taskContext *TaskContext) error {
	var patchNumber = 1

	if len(taskContext.topics) <= 0 {
		return fmt.Errorf("the topic is empty")
	}

	ctx, cancel := context.WithTimeout(context.Background(), time.Second*10)
	defer cancel()

	f, err := os.OpenFile(filepath.Join(o.CurrentPath, _seriesFile), os.O_CREATE|os.O_WRONLY|os.O_TRUNC, 0o644)
	if err != nil {
		return fmt.Errorf("write series file failed, err: %v", err)
	}
	defer f.Close()

	for _, topic := range taskContext.topics {
		var (
			stdout bytes.Buffer
			stderr bytes.Buffer
		)

		fmt.Printf("Generating %0.70s...", topic.GitBranch.BranchName)

		rangeArgument := fmt.Sprintf("%s..%s", o.GitVersion, topic.GitBranch.BranchName)
		if topic.DependIndex >= 0 {
			rangeArgument = fmt.Sprintf("%s..%s",
				taskContext.topics[topic.DependIndex].GitBranch.BranchName, topic.GitBranch.BranchName)
		}

		cmd, err := NewCommand(ctx, o.CurrentPath, nil, nil, &stdout, &stderr,
			"git", "format-patch", "-o", _outputFolderName,
			fmt.Sprintf("--start-number=%04d", patchNumber), rangeArgument)
		if err != nil {
			return fmt.Errorf("generate patch failed, err: %v", err)
		}

		if err = cmd.Wait(); err != nil {
			return fmt.Errorf("generate patch failed, stderr: %s, err: %v", stderr.String(), err)
		}

		scanner := bufio.NewScanner(bytes.NewReader(stdout.Bytes()))

		for scanner.Scan() {
			f.WriteString(fmt.Sprintf("t/%s\n", scanner.Text()))
			patchNumber++
		}

		fmt.Printf("\t done\n")
	}

	fmt.Println("Successfully generate all the patches")
	return nil
}
