package cmd

import (
	"fmt"
	"os"

	"github.com/spf13/cobra"
	agit_release "golang.aliyun-inc.com/agit/agit-release"
)

var autoCmd = &cobra.Command{
	Use:   "auto",
	Short: "",
	Run: func(cmd *cobra.Command, args []string) {
		if err := validateOptions(); err != nil {
			fmt.Println(err.Error())
			os.Exit(128)
		}

		taskContext := &agit_release.TaskContext{}
		tasks := &agit_release.ReleaseScheduler{}
		taskRemoteName := &agit_release.TaskRemoteName{}
		readVersion := &agit_release.AGitVersion{}
		readTopic := &agit_release.AGitTopicScheduler{}
		topicVerify := &agit_release.TopicVerify{}
		topicSort := &agit_release.TaskTopicSort{}
		generatePatches := &agit_release.GeneratePatches{}

		tasks.Next(readVersion, "read_version")
		readVersion.Next(taskRemoteName, "get_remote_name")
		taskRemoteName.Next(readTopic, "read_topic")
		readTopic.Next(topicVerify, "topic_verify")
		topicVerify.Next(topicSort, "topic_sort")
		topicSort.Next(generatePatches, "generate_patches")

		if err := tasks.Do(&agitOptions, taskContext); err != nil {
			fmt.Printf("%s", err.Error())
		}
	},
}

func init() {
	currentPath, err := os.Getwd()
	if err != nil {
		panic("cannot get current path: " + err.Error())
	}

	// If not provide the path, then it will use current path
	autoCmd.Flags().StringVarP(
		&agitOptions.CurrentPath,
		"path",
		"p",
		currentPath,
		"",
	)

	autoCmd.Flags().StringVarP(
		&agitOptions.ReleaseBranch,
		"release-branch",
		"r",
		"",
		"the release branch name",
	)

	autoCmd.Flags().StringVarP(
		&agitOptions.GitTargetVersion,
		"target-version",
		"t",
		"",
		"v2.36.1",
	)

	autoCmd.Flags().BoolVarP(
		&agitOptions.UseRemote,
		"use-remote",
		"",
		false,
		"if local and remote not same, then use remote branch",
	)

	autoCmd.Flags().BoolVarP(
		&agitOptions.UseLocal,
		"user-local",
		"",
		false,
		"if local and remote not same, then user local branch",
	)

	autoCmd.Flags().StringVarP(
		&agitOptions.RemoteName,
		"remote-name",
		"",
		"",
		"the remote name, default is origin",
	)

	autoCmd.Flags().StringVarP(
		&agitOptions.GitVersion,
		"git-version",
		"",
		"",
		"the git version, such as v2.36.1",
	)

	autoCmd.Flags().StringVarP(
		&agitOptions.AGitVersion,
		"agit-version",
		"",
		"",
		"the agit version, such as 6.5.9",
	)

	rootCmd.AddCommand(autoCmd)
}

func validateOptions() error {
	if agitOptions.UseRemote && agitOptions.UseLocal {
		return fmt.Errorf("'--use-local' and '--use-remote' cannot be used together")
	}

	if agitOptions.UseLocal {
		agitOptions.BranchMode = 1
	}

	if agitOptions.UseRemote {
		agitOptions.BranchMode = 2
	}

	return nil
}
