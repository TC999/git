package cmd

import (
	"fmt"
	"os"

	"github.com/spf13/cobra"
	agit_release "golang.aliyun-inc.com/agit/agit-release"
)

var agitOptions *agit_release.Options

var rootCmd = &cobra.Command{
	Use:   "",
	Short: "",
	Run: func(cmd *cobra.Command, args []string) {
		taskContext := &agit_release.TaskContext{}
		tasks := &agit_release.ReleaseScheduler{}
		readVersion := &agit_release.AGitVersion{}
		readTopic := &agit_release.AGitTopicScheduler{}
		topicVerify := &agit_release.TopicVerify{}

		tasks.Next(readVersion, "read_version")
		readVersion.Next(readTopic, "read_topic")
		readTopic.Next(topicVerify, "topic_verify")

		if err := tasks.Do(agitOptions, taskContext); err != nil {
			fmt.Printf("%s", err.Error())
		}
	},
}

func init() {
	Options := &agit_release.Options{}
	currentPath, err := os.Getwd()
	if err != nil {
		panic("cannot get current path: " + err.Error())
	}

	// If not provide the path, then it will use current path
	rootCmd.Flags().StringVarP(
		&Options.CurrentPath,
		"path",
		"p",
		currentPath,
		"",
	)

	rootCmd.Flags().StringVarP(
		&Options.ReleaseBranch,
		"release-branch",
		"r",
		"",
		"the release branch name",
	)

	rootCmd.Flags().StringVarP(
		&Options.GitTargetVersion,
		"target-version",
		"t",
		"",
		"v2.36.1",
	)

	rootCmd.Flags().BoolVarP(
		&Options.UseRemote,
		"use-remote",
		"u",
		false,
		"if local and remote not same, then use remote branch",
	)

	rootCmd.Flags().StringVarP(
		&Options.RemoteName,
		"remote-name",
		"",
		"origin",
		"the remote name, default is origin",
	)

	rootCmd.Flags().StringVarP(
		&Options.GitVersion,
		"git-version",
		"",
		"",
		"the git version, such as v2.36.1",
	)

	rootCmd.Flags().StringVarP(
		&Options.AGitVersion,
		"agit-version",
		"",
		"",
		"the agit version, such as 6.5.9",
	)

	agitOptions = Options
}

func Execute() {
	if err := rootCmd.Execute(); err != nil {
		fmt.Println(err)
		os.Exit(128)
	}
}
