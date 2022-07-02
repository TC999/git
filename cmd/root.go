package cmd

import (
	"fmt"
	"os"

	"github.com/spf13/cobra"
)

var AGitOptions Options

type Options struct {
	CurrentPath      string
	ReleaseBranch    string
	GitTargetVersion string
	UseLocal         bool
	UseRemote        bool

	GitVersion  string
	AGitVersion string
}

var rootCmd = &cobra.Command{
	Use:   "",
	Short: "",
	Run: func(cmd *cobra.Command, args []string) {
		fmt.Println("execute")
	},
}

func init() {
	Options := &Options{}
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

	rootCmd.Flags().BoolVarP(
		&Options.UseLocal,
		"use-local",
		"l",
		false,
		"if local and remote not same, then use local branch",
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
}

func Execute() {
	if err := rootCmd.Execute(); err != nil {
		fmt.Println(err)
		os.Exit(128)
	}
}
