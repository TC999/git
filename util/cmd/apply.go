package cmd

import (
	"fmt"
	"os"

	"github.com/spf13/cobra"
	"golang.aliyun-inc.com/agit/patchwork"
)

var applyCmd = &cobra.Command{
	Use:   "apply-patches",
	Short: "",
	Run: func(cmd *cobra.Command, args []string) {
		taskContext := &patchwork.TaskContext{}
		tasks := &patchwork.ReleaseScheduler{}
		readVersion := &patchwork.AGitVersion{}
		applyTopic := &patchwork.TaskApplyTopic{}
		tasks.Next(readVersion, "read_version")
		readVersion.Next(applyTopic, "apply_topic")

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
		&agitOptions.ApplyTo,
		"apply-to",
		"",
		"",
		"the folder to apply(It must be a git repo and have the git tags)",
	)

	rootCmd.AddCommand(applyCmd)
}
