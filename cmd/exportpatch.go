package cmd

import (
	"fmt"
	"os"

	"github.com/spf13/cobra"
	"golang.aliyun-inc.com/agit/patchwork"
)

var exportPatchCmd = &cobra.Command{
	Use:   "export-patch",
	Short: "",
	Run: func(cmd *cobra.Command, args []string) {
		if err := validateOptions(); err != nil {
			fmt.Println(err.Error())
			os.Exit(128)
		}

		taskContext := &patchwork.TaskContext{}
		tasks := &patchwork.ReleaseScheduler{}
		taskRemoteName := &patchwork.TaskRemoteName{}
		readVersion := &patchwork.AGitVersion{}
		readTopic := &patchwork.AGitTopicScheduler{}
		topicSort := &patchwork.TaskTopicSort{}
		generatePatches := &patchwork.GeneratePatches{}
		taskTopicTest := &patchwork.TaskTopicTest{}

		tasks.Next(readVersion, "read_version")
		readVersion.Next(taskRemoteName, "get_remote_name")
		taskRemoteName.Next(readTopic, "read_topic")
		readTopic.Next(topicSort, "topic_sort")
		topicSort.Next(generatePatches, "generate_patches")
		generatePatches.Next(taskTopicTest, "generate_series_test")
		taskTopicTest.Next(nil, "no_task")

		if err := tasks.Do(&agitOptions, taskContext); err != nil {
			fmt.Printf("%s", err.Error())
			os.Exit(1)
		}
	},
}

func init() {
	currentPath, err := os.Getwd()
	if err != nil {
		panic("cannot get current path: " + err.Error())
	}

	// If not provide the path, then it will use current path
	exportPatchCmd.Flags().StringVarP(
		&agitOptions.CurrentPath,
		"path",
		"p",
		currentPath,
		"",
	)

	exportPatchCmd.Flags().BoolVarP(
		&agitOptions.UseRemote,
		"use-remote",
		"",
		false,
		"if local and remote not same, then use remote branch",
	)

	exportPatchCmd.Flags().BoolVarP(
		&agitOptions.UseLocal,
		"user-local",
		"",
		false,
		"if local and remote not same, then user local branch",
	)

	exportPatchCmd.Flags().StringVarP(
		&agitOptions.RemoteName,
		"remote-name",
		"",
		"",
		"the remote name, default is origin",
	)

	exportPatchCmd.Flags().StringVarP(
		&agitOptions.GitVersion,
		"git-version",
		"",
		"",
		"the git version, such as v2.36.1",
	)

	exportPatchCmd.Flags().StringVarP(
		&agitOptions.AGitVersion,
		"agit-version",
		"",
		"",
		"the agit version, such as 6.5.9",
	)

	rootCmd.AddCommand(exportPatchCmd)
}
