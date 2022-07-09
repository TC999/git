package cmd

import (
	"fmt"
	"os"

	"github.com/spf13/cobra"
	agit_release "golang.aliyun-inc.com/agit/agit-release"
)

var applyCmd = &cobra.Command{
	Use:   "apply",
	Short: "",
	Run: func(cmd *cobra.Command, args []string) {
		taskContext := &agit_release.TaskContext{}
		tasks := &agit_release.ReleaseScheduler{}
		applyTopic := &agit_release.TaskApplyTopic{}
		tasks.Next(applyTopic, "apply_topic")
		if err := tasks.Do(&agitOptions, taskContext); err != nil {
			fmt.Println(err)
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
	applyCmd.Flags().StringVarP(
		&agitOptions.CurrentPath,
		"path",
		"p",
		currentPath,
		"",
	)

	applyCmd.Flags().StringVarP(
		&agitOptions.ReleaseBranch,
		"release-branch",
		"r",
		"",
		"the release branch name",
	)

	rootCmd.AddCommand(applyCmd)
}
