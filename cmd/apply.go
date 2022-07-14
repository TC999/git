package cmd

import (
	"fmt"
	"os"

	"github.com/spf13/cobra"
	"golang.aliyun-inc.com/agit/patchwork"
)

var applyCmd = &cobra.Command{
	Use:   "apply",
	Short: "",
	Run: func(cmd *cobra.Command, args []string) {
		taskContext := &patchwork.TaskContext{}
		tasks := &patchwork.ReleaseScheduler{}
		applyTopic := &patchwork.TaskApplyTopic{}
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
		"agit-master",
		"the release branch name",
	)

	rootCmd.AddCommand(applyCmd)
}
