package cmd

import (
	"fmt"
	"os"

	"github.com/spf13/cobra"
	agit_release "golang.aliyun-inc.com/agit/agit-release"
)

var exportTestCmd = &cobra.Command{
	Use:   "export-test",
	Short: "",
	Run: func(cmd *cobra.Command, args []string) {
		taskContext := &agit_release.TaskContext{}
		tasks := &agit_release.ReleaseScheduler{}
		taskRemoteName := &agit_release.TaskRemoteName{}
		readVersion := &agit_release.AGitVersion{}
		readTopic := &agit_release.AGitTopicScheduler{}
		topicVerify := &agit_release.TopicVerify{}
		topicSort := &agit_release.TaskTopicSort{}
		taskExportTest := &agit_release.TaskTopicTest{}

		tasks.Next(readVersion, "read_version")
		readVersion.Next(taskRemoteName, "get_remote_name")
		taskRemoteName.Next(readTopic, "read_topic")
		readTopic.Next(topicVerify, "topic_verify")
		topicVerify.Next(topicSort, "topic_sort")
		topicSort.Next(taskExportTest, "export_topic_test")

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

	exportTestCmd.Flags().StringVarP(
		&agitOptions.CurrentPath,
		"path",
		"p",
		currentPath,
		"",
	)

	exportTestCmd.Flags().StringVarP(
		&agitOptions.GitVersion,
		"git-version",
		"",
		"",
		"the git version, such as v2.36.1",
	)

	rootCmd.AddCommand(exportTestCmd)
}
