package agit_release

import (
	"fmt"
	"os"
	"path"
	"testing"

	"golang.aliyun-inc.com/agit/agit-release/cmd"
)

const (
	_gitVersionFileType = iota
	_agitVersionFileType
)

// createFile used for create test file
func createFile(testPath string, fileType int, contents string) error {
	var filePath string
	switch fileType {
	case _gitVersionFileType:
		filePath = path.Join(testPath, _gitVersion)
	case _agitVersionFileType:
		filePath = path.Join(testPath, _agitVersion)
	default:
		return fmt.Errorf("invalid filetype :%d", fileType)
	}

	f, err := os.OpenFile(filePath, os.O_CREATE|os.O_WRONLY, 0o644)
	if err != nil {
		return err
	}
	defer f.Close()

	_, err = f.WriteString(contents)
	return err
}

func TestVersionCheck(t *testing.T) {
	testPath := t.TempDir()

	cleanup := func() {
		os.RemoveAll(path.Join(testPath, _agitVersion))
		os.RemoveAll(path.Join(testPath, _gitVersion))
	}

	type fields struct {
		next     Scheduler
		nextName string
	}
	type args struct {
		o *cmd.Options
	}
	tests := []struct {
		name          string
		fields        fields
		args          args
		filePrepareFn func() error
		cleanup       func()
		agitVersion   string
		gitVersion    string
		wantErr       bool
	}{
		{
			name:   "two_version_files_exist",
			fields: fields{},
			args: args{
				o: &cmd.Options{
					CurrentPath: testPath,
				},
			},
			filePrepareFn: func() error {
				if err := createFile(testPath, _gitVersionFileType, "2.36.1"); err != nil {
					return err
				}

				if err := createFile(testPath, _agitVersionFileType, "6.5.9"); err != nil {
					return err
				}

				return nil
			},
			cleanup:     cleanup,
			agitVersion: "6.5.9",
			gitVersion:  "2.36.1",
			wantErr:     false,
		},
		{
			name:   "only_git_version_file_exist",
			fields: fields{},
			args: args{
				o: &cmd.Options{
					CurrentPath: testPath,
				},
			},
			filePrepareFn: func() error {
				return createFile(testPath, _gitVersionFileType, "2.36.1")
			},
			cleanup: cleanup,
			wantErr: true,
		},
		{
			name:   "only_agit_version_file",
			fields: fields{},
			args: args{
				o: &cmd.Options{
					CurrentPath: testPath,
				},
			},
			filePrepareFn: func() error {
				return createFile(testPath, _agitVersionFileType, "6.5.9")
			},
			cleanup: cleanup,
			wantErr: true,
		},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			a := &AGitVersion{
				next:     tt.fields.next,
				nextName: tt.fields.nextName,
			}

			if err := tt.filePrepareFn(); err != nil {
				t.Errorf("create prepare files failed")
			}

			defer func() {
				tt.cleanup()
			}()

			if err := a.Do(tt.args.o); (err != nil) != tt.wantErr {
				t.Errorf("Do() error = %v, wantErr %v", err, tt.wantErr)
			}

			if tt.agitVersion != "" && tt.agitVersion != tt.args.o.AGitVersion {
				t.Errorf("agit version invalid")
			}

			if tt.gitVersion != "" && tt.gitVersion != tt.args.o.GitVersion {
				t.Errorf("git version invlaid")
			}

		})
	}
}

func TestAGitVersion_Next(t *testing.T) {
	type fields struct {
		next     Scheduler
		nextName string
	}
	type args struct {
		scheduler Scheduler
		name      string
	}
	tests := []struct {
		name    string
		fields  fields
		args    args
		wantErr bool
	}{
		// TODO: Add test cases.
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			a := AGitVersion{
				next:     tt.fields.next,
				nextName: tt.fields.nextName,
			}
			if err := a.Next(tt.args.scheduler, tt.args.name); (err != nil) != tt.wantErr {
				t.Errorf("Next() error = %v, wantErr %v", err, tt.wantErr)
			}
		})
	}
}
