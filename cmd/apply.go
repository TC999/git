package cmd

import (
	"fmt"
	"os"

	"github.com/spf13/cobra"
	agit_release "golang.aliyun-inc.com/agit/agit-release"
)

var ApplyCmd = &cobra.Command{
	Use:   "",
	Short: "",
	Run: func(cmd *cobra.Command, args []string) {
		taskContext := &agit_release.TaskContext{}
		tasks := &agit_release.ReleaseScheduler{}
		applyTopic := &agit_release.TaskApplyTopic{}
		tasks.Next(applyTopic, "apply_topic")
		if err := tasks.Do(agitOptions, taskContext); err != nil {
			fmt.Println(err)
			os.Exit(1)
		}
	},
}
