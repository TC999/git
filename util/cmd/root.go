package cmd

import (
	"fmt"
	"os"

	"github.com/spf13/cobra"
	"golang.aliyun-inc.com/agit/patchwork"
)

var (
	rootCmd     = &cobra.Command{}
	agitOptions = patchwork.Options{}
)

func Execute() {
	if err := rootCmd.Execute(); err != nil {
		fmt.Println(err)
		os.Exit(128)
	}
}
