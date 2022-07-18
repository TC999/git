package patchwork

import (
	"os"
	"path/filepath"
	"testing"
)

func TestTrimTopicPrefixNumber(t *testing.T) {
	type args struct {
		topicName string
	}
	tests := []struct {
		name string
		args args
		want string
	}{
		{
			name: "successfully",
			args: args{
				topicName: "topic/0001-agit-txn",
			},
			want: "topic/agit-txn",
		},
		{
			name: "only_one_number",
			args: args{
				topicName: "topic/1-agit-txn",
			},
			want: "topic/agit-txn",
		},
		{
			name: "no_number",
			args: args{
				topicName: "topic/agit-txn",
			},
			want: "topic/agit-txn",
		},
		{
			// We do not support without dash after number,
			// this case just record this case.
			name: "no_dash_after_number",
			args: args{
				topicName: "topic/0001agit-txn",
			},
			want: "topic/0001agit-txn",
		},
		{
			name: "no_topic_prefix_and_with_number",
			args: args{
				topicName: "0001-agit-txn",
			},
			want: "topic/agit-txn",
		},
		{
			name: "no_topic_prefix_and_no_number",
			args: args{
				topicName: "agit-txn",
			},
			want: "topic/agit-txn",
		},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			if got := TrimTopicPrefixNumber(tt.args.topicName); got != tt.want {
				t.Errorf("TrimTopicPrefixNumber() = %v, want %v", got, tt.want)
			}
		})
	}
}

func TestFindLastLineFromEndAndReplace(t *testing.T) {
	tmpFilePath := filepath.Join(t.TempDir(), "tmpfile-for-read")

	prepareTestFile := func(filePath string) error {
		tmpFile, err := os.Create(tmpFilePath)
		if err != nil {
			t.Fatalf("create tmpfile for read failed, err: %v", err)
		}
		defer tmpFile.Close()

		tmpFile.WriteString(`
this is a test
second line
third line
abcdefgh
Today is Monday
`)
		return nil
	}

	type args struct {
		filePath string
		new      string
		old      string
	}
	tests := []struct {
		name          string
		args          args
		fileProcessor func(filepath string) error
		wantErr       bool
		expectFile    string
	}{
		{
			name: "end_without_newline_successfully",
			args: args{
				filePath: tmpFilePath,
				old:      "this is append line",
				new:      "removed the append",
			},
			fileProcessor: func(filepath string) error {
				f, err := os.OpenFile(filepath, os.O_WRONLY|os.O_APPEND, 0644)
				if err != nil {
					return err
				}
				defer f.Close()

				f.WriteString("this is append line")
				return nil
			},
			expectFile: `
this is a test
second line
third line
abcdefgh
Today is Monday
removed the append
`,
			wantErr: false,
		},
		{
			name: "end_with_newline_successfully",
			args: args{
				filePath: tmpFilePath,
				old:      "this is append line",
				new:      "removed new line",
			},
			fileProcessor: func(filepath string) error {
				f, err := os.OpenFile(filepath, os.O_WRONLY|os.O_APPEND, 0644)
				if err != nil {
					return err
				}
				defer f.Close()

				f.WriteString("this is append line")
				f.WriteString("\n")
				return nil
			},
			expectFile: `
this is a test
second line
third line
abcdefgh
Today is Monday
removed new line
`,
			wantErr: false,
		},
		{
			name: "end_with_multiple_newline_successfully",
			args: args{
				filePath: tmpFilePath,
				old:      "this is append line",
				new:      "multiple line test",
			},
			fileProcessor: func(filepath string) error {
				f, err := os.OpenFile(filepath, os.O_WRONLY|os.O_APPEND, 0644)
				if err != nil {
					return err
				}
				defer f.Close()

				f.WriteString("this is append line")
				f.WriteString("\n")
				f.WriteString("\n")
				f.WriteString("\n")
				return nil
			},
			expectFile: `
this is a test
second line
third line
abcdefgh
Today is Monday
multiple line test
`,
			wantErr: false,
		},
		{
			name: "not_found_old",
			args: args{
				filePath: tmpFilePath,
				old:      "not exist line",
				new:      "need failed",
			},
			fileProcessor: func(filepath string) error {
				return nil
			},
			wantErr: true,
		},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			if err := prepareTestFile(tmpFilePath); err != nil {
				t.Fatal("prepare test file failed")
			}

			if err := tt.fileProcessor(tmpFilePath); err != nil {
				t.Fatal("process read file failed")
			}

			err := FindLastLineFromEndAndReplace(tt.args.filePath, tt.args.old, tt.args.new)
			if (err != nil) != tt.wantErr {
				t.Errorf("FindLastLineFromEndAndReplace() error = %v, wantErr %v", err, tt.wantErr)
				return
			}

			contents, _ := os.ReadFile(tmpFilePath)
			if err == nil && string(contents) != tt.expectFile {
				t.Errorf("FindLastLineFromEndAndReplace return contents invalid, want: %s, got: %s",
					tt.expectFile, string(contents))
			}
		})
	}
}
