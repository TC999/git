package agit_release

import (
	"bytes"
	"context"
	"fmt"
	"path/filepath"
	"reflect"
	"testing"
	"time"

	testspace "github.com/Jiu2015/gotestspace"
	"golang.aliyun-inc.com/agit/agit-release/cmd"
)

var (
	topicBasicRepo testspace.Space
)

func prepareBranchRepo(t *testing.T, branches []string) testspace.Space {
	var references bytes.Buffer
	for _, branch := range branches {
		references.WriteString(branch + " ")
	}

	branchTestspace, err := testspace.Create(
		testspace.WithPathOption(filepath.Join(t.TempDir(), "testspace-*")),
		testspace.WithEnvironmentsOption(
			fmt.Sprintf("references=%s", references.String()),
		),
		testspace.WithShellOption(`
git -c init.defaultBranch=master init --bare base.git && \
git clone base.git workdir &&
cd workdir &&
(
	file=1;
	for item in $references;
	do
		echo $item>$file
		git add .
		test_tick
		git commit -m $item
		git branch $item
	done
)
`))
	if err != nil {
		t.Fatal("cannot create testrepo")
	}

	return branchTestspace
}

func TestAGitTopicScheduler_ReadLocalTopicBranch(t *testing.T) {
	ctx, cancel := context.WithTimeout(context.Background(), time.Second*10)
	defer cancel()

	type args struct {
		o *cmd.Options
	}
	tests := []struct {
		name           string
		args           args
		createBranchFn func() (testspace.Space, string, error)
		wantErr        bool
		wantBranch     []string
	}{
		{
			name: "successfully",
			args: args{
				o: &cmd.Options{},
			},
			createBranchFn: func() (testspace.Space, string, error) {
				repoSpace := prepareBranchRepo(t, []string{"topic/001-branch1", "topic/002-branch2"})
				_, _, err := repoSpace.Execute(ctx, "git branch -a")
				return repoSpace, repoSpace.GetPath("workdir"), err
			},
			wantErr: false,
			wantBranch: []string{
				"topic/001-branch1",
				"topic/002-branch2",
			},
		},
		{
			name: "none_branch",
			args: args{
				o: &cmd.Options{},
			},
			createBranchFn: func() (testspace.Space, string, error) {
				repoSpace := prepareBranchRepo(t, []string{})
				return repoSpace, repoSpace.GetPath("workdir"), nil
			},
			wantErr:    false,
			wantBranch: []string{},
		},
		{
			name: "one_topic_and_one_other_branch",
			args: args{
				o: &cmd.Options{},
			},
			createBranchFn: func() (testspace.Space, string, error) {
				repoSpace := prepareBranchRepo(t, []string{"topic/001-branch1", "002-branch2"})
				_, _, err := repoSpace.Execute(ctx, "git branch -a")
				return repoSpace, repoSpace.GetPath("workdir"), err
			},
			wantErr: false,
			wantBranch: []string{
				"topic/001-branch1",
			},
		},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			a := &AGitTopicScheduler{}

			repoSpace, repoPath, err := tt.createBranchFn()
			if err != nil {
				t.Errorf("prepare repo failed")
			}
			defer repoSpace.Cleanup()

			// Set the repo path
			tt.args.o.CurrentPath = repoPath

			if err := a.ReadLocalTopicBranch(tt.args.o); (err != nil) != tt.wantErr {
				t.Errorf("ReadLocalTopicBranch() error = %v, wantErr %v", err, tt.wantErr)
			}

			if len(tt.wantBranch) > 0 {
				for _, b := range tt.wantBranch {
					var find bool

					for _, v := range a.localTopicBranches {
						if v.BranchName == b {
							find = true
							break
						}
					}

					if !find {
						t.Errorf("the branch count invalid, want %d, got %d",
							len(tt.wantBranch), len(a.localTopicBranches))
					}
				}
			}
		})
	}
}

func TestAGitTopicScheduler_ReadRemoteTopicBranch(t *testing.T) {
	ctx, cancel := context.WithTimeout(context.Background(), time.Second*10)
	defer cancel()

	type fields struct {
		next                Scheduler
		nextName            string
		topics              []*Topic
		localTopicBranches  map[string]*Branch
		remoteTopicBranches map[string]*Branch
	}
	type args struct {
		o *cmd.Options
	}
	tests := []struct {
		name           string
		args           args
		createBranchFn func() (testspace.Space, string, error)
		wantErr        bool
		wantBranch     []string
	}{
		{
			name: "successfully",
			args: args{
				o: &cmd.Options{
					RemoteName: "origin",
				},
			},
			createBranchFn: func() (testspace.Space, string, error) {
				repoSpace := prepareBranchRepo(t, []string{"topic/001-branch1", "topic/002-branch2"})
				_, _, err := repoSpace.Execute(ctx, "cd workdir && git push --all")
				if err != nil {
					return nil, "", err
				}

				_, _, err = repoSpace.Execute(ctx, "rm -rf workdir && git clone base.git workdir")
				return repoSpace, repoSpace.GetPath("workdir"), err
			},
			wantErr: false,
			wantBranch: []string{
				"topic/001-branch1",
				"topic/002-branch2",
			},
		},
		{
			name: "none_branch",
			args: args{
				o: &cmd.Options{
					RemoteName: "origin",
				},
			},
			createBranchFn: func() (testspace.Space, string, error) {
				repoSpace := prepareBranchRepo(t, []string{})
				return repoSpace, repoSpace.GetPath("workdir"), nil
			},
			wantErr:    false,
			wantBranch: []string{},
		},
		{
			name: "one_topic_and_one_other_branch",
			args: args{
				o: &cmd.Options{
					RemoteName: "origin",
				},
			},
			createBranchFn: func() (testspace.Space, string, error) {
				repoSpace := prepareBranchRepo(t, []string{"topic/001-branch1", "002-branch2"})
				_, _, err := repoSpace.Execute(ctx, "cd workdir && git push --all")
				if err != nil {
					return nil, "", err
				}

				_, _, err = repoSpace.Execute(ctx, "rm -rf workdir && git clone base.git workdir")
				return repoSpace, repoSpace.GetPath("workdir"), err
			},
			wantErr: false,
			wantBranch: []string{
				"topic/001-branch1",
			},
		},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			a := &AGitTopicScheduler{}

			repoSpace, repoPath, err := tt.createBranchFn()
			if err != nil {
				t.Errorf("prepare repo failed")
			}
			defer repoSpace.Cleanup()

			// Set the repo path
			tt.args.o.CurrentPath = repoPath

			if err := a.ReadRemoteTopicBranch(tt.args.o); (err != nil) != tt.wantErr {
				t.Errorf("ReadRemoteTopicBranch() error = %v, wantErr %v", err, tt.wantErr)
			}

			if len(tt.wantBranch) > 0 {
				for _, b := range tt.wantBranch {
					var find bool

					for _, v := range a.remoteTopicBranches {
						if v.BranchName == b {
							find = true
							break
						}
					}

					if !find {
						t.Errorf("the branch count invalid, want %d, got %d",
							len(tt.wantBranch), len(a.remoteTopicBranches))
					}
				}
			}
		})
	}
}

func TestAGitTopicScheduler_GetTopics(t *testing.T) {
	ctx, cancel := context.WithTimeout(context.Background(), time.Second*10)
	defer cancel()

	type args struct {
		o *cmd.Options
	}
	tests := []struct {
		name           string
		args           args
		createBranchFn func() (testspace.Space, string, error)
		wantErr        bool
		wantTopic      []*Topic
	}{
		{
			name: "no_depend_successfully",
			args: args{
				o: &cmd.Options{
					RemoteName: "origin",
				},
			},
			createBranchFn: func() (testspace.Space, string, error) {
				repoSpace := prepareBranchRepo(t, []string{"topic/001-branch1", "topic/002-branch2"})
				_, _, err := repoSpace.Execute(ctx, "cd workdir && git push --all")
				if err != nil {
					return nil, "", err
				}

				_, _, err = repoSpace.Execute(ctx, `
					cd workdir && 
					printf "topic/branch1\ntopic/branch2" >topic.txt
				`)
				if err != nil {
					return nil, "", err
				}

				return repoSpace, repoSpace.GetPath("workdir"), nil
			},
			wantErr: false,
			wantTopic: []*Topic{
				{
					TopicName:   "topic/branch1",
					DependIndex: -1,
					BranchType:  1,
					GitBranch: &Branch{
						BranchName: "topic/001-branch1",
						Reference:  "63f12b3fd491c12c4b5398848b64624c1ba5a0d1",
					},
				},
				{
					TopicName:   "topic/branch2",
					DependIndex: -1,
					BranchType:  1,
					GitBranch: &Branch{
						BranchName: "topic/002-branch2",
						Reference:  "763d856f16e3d9f8bd643e50badfde04dc907a52",
					},
				},
			},
		},
		{
			name: "with_valid_depend",
			args: args{
				o: &cmd.Options{
					RemoteName: "origin",
				},
			},
			createBranchFn: func() (testspace.Space, string, error) {
				repoSpace := prepareBranchRepo(t, []string{"topic/001-branch1", "topic/002-branch2", "topic/003-branch3"})
				_, _, err := repoSpace.Execute(ctx, "cd workdir && git push --all")
				if err != nil {
					return nil, "", err
				}

				_, _, err = repoSpace.Execute(ctx, `
					cd workdir && 
					printf "topic/branch1\ntopic/branch2:topic/branch1\ntopic/003-branch3" >topic.txt
				`)
				if err != nil {
					return nil, "", err
				}

				return repoSpace, repoSpace.GetPath("workdir"), nil
			},
			wantErr: false,
			wantTopic: []*Topic{
				{
					TopicName:   "topic/branch1",
					DependIndex: -1,
					BranchType:  1,
					GitBranch: &Branch{
						BranchName: "topic/001-branch1",
						Reference:  "63f12b3fd491c12c4b5398848b64624c1ba5a0d1",
					},
				},
				{
					TopicName:   "topic/branch2",
					DependIndex: 0,
					BranchType:  1,
					GitBranch: &Branch{
						BranchName: "topic/002-branch2",
						Reference:  "763d856f16e3d9f8bd643e50badfde04dc907a52",
					},
				},
				{
					TopicName:   "topic/003-branch3",
					DependIndex: -1,
					BranchType:  1,
					GitBranch: &Branch{
						BranchName: "topic/003-branch3",
						Reference:  "78a8d04e87cd6c119f8ae31da2c17d312fe27d9e",
					},
				},
			},
		},
		{
			name: "with_invalid_depend",
			args: args{
				o: &cmd.Options{
					RemoteName: "origin",
				},
			},
			createBranchFn: func() (testspace.Space, string, error) {
				repoSpace := prepareBranchRepo(t, []string{"topic/001-branch1", "topic/002-branch2", "topic/003-branch3"})
				_, _, err := repoSpace.Execute(ctx, "cd workdir && git push --all")
				if err != nil {
					return nil, "", err
				}

				_, _, err = repoSpace.Execute(ctx, `
					cd workdir && 
					printf "topic/branch1\ntopic/branch2:topic/branch21\ntopic/003-branch3" >topic.txt
				`)
				if err != nil {
					return nil, "", err
				}

				return repoSpace, repoSpace.GetPath("workdir"), nil
			},
			wantErr: true,
			wantTopic: []*Topic{
				{
					TopicName:   "topic/branch1",
					DependIndex: -1,
					BranchType:  1,
					GitBranch: &Branch{
						BranchName: "topic/001-branch1",
						Reference:  "63f12b3fd491c12c4b5398848b64624c1ba5a0d1",
					},
				},
				{
					TopicName:   "topic/branch2",
					DependIndex: 0,
					BranchType:  1,
					GitBranch: &Branch{
						BranchName: "topic/002-branch2",
						Reference:  "763d856f16e3d9f8bd643e50badfde04dc907a52",
					},
				},
				{
					TopicName:   "topic/003-branch3",
					DependIndex: -1,
					BranchType:  1,
					GitBranch: &Branch{
						BranchName: "topic/003-branch3",
						Reference:  "78a8d04e87cd6c119f8ae31da2c17d312fe27d9e",
					},
				},
			},
		},
		{
			name: "only_remote_on_repo",
			args: args{
				o: &cmd.Options{
					RemoteName: "origin",
				},
			},
			createBranchFn: func() (testspace.Space, string, error) {
				repoSpace := prepareBranchRepo(t, []string{"topic/001-branch1", "topic/002-branch2"})
				_, _, err := repoSpace.Execute(ctx, "cd workdir && git push --all && cd .. && rm -rf workdir")
				if err != nil {
					return nil, "", err
				}

				_, _, err = repoSpace.Execute(ctx, `
					git clone base.git workdir &&
					cd workdir && 
					printf "topic/branch1\ntopic/branch2" >topic.txt
				`)
				if err != nil {
					return nil, "", err
				}

				return repoSpace, repoSpace.GetPath("workdir"), nil
			},
			wantErr: false,
			wantTopic: []*Topic{
				{
					TopicName:   "topic/branch1",
					DependIndex: -1,
					BranchType:  2,
					GitBranch: &Branch{
						BranchName: "topic/001-branch1",
						Reference:  "63f12b3fd491c12c4b5398848b64624c1ba5a0d1",
					},
				},
				{
					TopicName:   "topic/branch2",
					DependIndex: -1,
					BranchType:  2,
					GitBranch: &Branch{
						BranchName: "topic/002-branch2",
						Reference:  "763d856f16e3d9f8bd643e50badfde04dc907a52",
					},
				},
			},
		},
		{
			name: "remote_valid_depend",
			args: args{
				o: &cmd.Options{
					RemoteName: "origin",
				},
			},
			createBranchFn: func() (testspace.Space, string, error) {
				repoSpace := prepareBranchRepo(t, []string{"topic/001-branch1", "topic/002-branch2", "topic/003-branch3"})
				_, _, err := repoSpace.Execute(ctx, "cd workdir && git push --all && cd .. && rm -rf workdir")
				if err != nil {
					return nil, "", err
				}

				_, _, err = repoSpace.Execute(ctx, `
					git clone base.git workdir &&
					cd workdir && 
					printf "topic/branch1\ntopic/branch2:topic/branch1\ntopic/003-branch3" >topic.txt
				`)
				if err != nil {
					return nil, "", err
				}

				return repoSpace, repoSpace.GetPath("workdir"), nil
			},
			wantErr: false,
			wantTopic: []*Topic{
				{
					TopicName:   "topic/branch1",
					DependIndex: -1,
					BranchType:  2,
					GitBranch: &Branch{
						BranchName: "topic/001-branch1",
						Reference:  "63f12b3fd491c12c4b5398848b64624c1ba5a0d1",
					},
				},
				{
					TopicName:   "topic/branch2",
					DependIndex: 0,
					BranchType:  2,
					GitBranch: &Branch{
						BranchName: "topic/002-branch2",
						Reference:  "763d856f16e3d9f8bd643e50badfde04dc907a52",
					},
				},
				{
					TopicName:   "topic/003-branch3",
					DependIndex: -1,
					BranchType:  2,
					GitBranch: &Branch{
						BranchName: "topic/003-branch3",
						Reference:  "78a8d04e87cd6c119f8ae31da2c17d312fe27d9e",
					},
				},
			},
		},
		{
			name: "repo_not_exist_branch",
			args: args{
				o: &cmd.Options{
					RemoteName: "origin",
				},
			},
			createBranchFn: func() (testspace.Space, string, error) {
				repoSpace := prepareBranchRepo(t, []string{"topic/001-branch1"})
				_, _, err := repoSpace.Execute(ctx, "cd workdir && git push --all")
				if err != nil {
					return nil, "", err
				}

				_, _, err = repoSpace.Execute(ctx, `
					cd workdir && 
					printf "topic/branch1\ntopic/branch2" >topic.txt
				`)
				if err != nil {
					return nil, "", err
				}

				return repoSpace, repoSpace.GetPath("workdir"), nil
			},
			wantErr: true,
			wantTopic: []*Topic{
				{
					TopicName:   "topic/branch1",
					DependIndex: -1,
					BranchType:  1,
					GitBranch: &Branch{
						BranchName: "topic/001-branch1",
						Reference:  "63f12b3fd491c12c4b5398848b64624c1ba5a0d1",
					},
				},
				{
					TopicName:   "topic/branch2",
					DependIndex: -1,
					BranchType:  1,
					GitBranch: &Branch{
						BranchName: "topic/002-branch2",
						Reference:  "763d856f16e3d9f8bd643e50badfde04dc907a52",
					},
				},
			},
		},
		{
			name: "ignore_code_comment",
			args: args{
				o: &cmd.Options{
					RemoteName: "origin",
				},
			},
			createBranchFn: func() (testspace.Space, string, error) {
				repoSpace := prepareBranchRepo(t, []string{"topic/001-branch1", "topic/002-branch2"})
				_, _, err := repoSpace.Execute(ctx, "cd workdir && git push --all")
				if err != nil {
					return nil, "", err
				}

				_, _, err = repoSpace.Execute(ctx, `
					cd workdir && 
					printf "topic/branch1\n#topic/branch2" >topic.txt
				`)
				if err != nil {
					return nil, "", err
				}

				return repoSpace, repoSpace.GetPath("workdir"), nil
			},
			wantErr: false,
			wantTopic: []*Topic{
				{
					TopicName:   "topic/branch1",
					DependIndex: -1,
					BranchType:  1,
					GitBranch: &Branch{
						BranchName: "topic/001-branch1",
						Reference:  "63f12b3fd491c12c4b5398848b64624c1ba5a0d1",
					},
				},
			},
		},
		{
			name: "use_remote_branch",
			args: args{
				o: &cmd.Options{
					RemoteName: "origin",
					UseRemote:  true,
				},
			},
			createBranchFn: func() (testspace.Space, string, error) {
				repoSpace := prepareBranchRepo(t, []string{"topic/001-branch1", "topic/002-branch2"})
				_, _, err := repoSpace.Execute(ctx, "cd workdir && git push --all")
				if err != nil {
					return nil, "", err
				}

				_, _, err = repoSpace.Execute(ctx, `
					cd workdir && 
					printf "topic/branch1\ntopic/branch2" >topic.txt
				`)
				if err != nil {
					return nil, "", err
				}

				return repoSpace, repoSpace.GetPath("workdir"), nil
			},
			wantErr: false,
			wantTopic: []*Topic{
				{
					TopicName:   "topic/branch1",
					DependIndex: -1,
					BranchType:  2,
					GitBranch: &Branch{
						BranchName: "topic/001-branch1",
						Reference:  "63f12b3fd491c12c4b5398848b64624c1ba5a0d1",
					},
				},
				{
					TopicName:   "topic/branch2",
					DependIndex: -1,
					BranchType:  2,
					GitBranch: &Branch{
						BranchName: "topic/002-branch2",
						Reference:  "763d856f16e3d9f8bd643e50badfde04dc907a52",
					},
				},
			},
		},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			a := &AGitTopicScheduler{}

			testSpace, path, err := tt.createBranchFn()
			if err != nil {
				t.Fatal("create test repo failed")
			}
			defer testSpace.Cleanup()

			tt.args.o.CurrentPath = path

			if err := a.GetTopics(tt.args.o); (err != nil) != tt.wantErr {
				t.Errorf("GetTopics() error = %v, wantErr %v", err, tt.wantErr)
			}

			if !tt.wantErr && !reflect.DeepEqual(tt.wantTopic, a.topics) {
				t.Errorf("the topic invalid")
			}
		})
	}
}
