package patchwork

import (
	"reflect"
	"testing"
)

func Test_processSeriesLine(t *testing.T) {
	type args struct {
		line string
	}
	tests := []struct {
		name    string
		args    args
		want    *Series
		wantErr bool
	}{
		{
			name: "successfully",
			args: args{
				line: "t/0001-patches.patches -p9 # abcd",
			},
			want: &Series{
				PatchName: "t/0001-patches.patches",
				Level:     "-p9",
			},
			wantErr: false,
		},
		{
			name: "level_start_with_#",
			args: args{
				line: "t/0001-patches.patches # -p9 # abcd",
			},
			want: &Series{
				PatchName: "t/0001-patches.patches",
			},
			wantErr: false,
		},
		{
			name: "the_line_start_with_E",
			args: args{
				line: "# t/0001-patches.patches",
			},
			want:    nil,
			wantErr: true,
		},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			got, err := processSeriesLine(tt.args.line)
			if (err != nil) != tt.wantErr {
				t.Errorf("processSeriesLine() error = %v, wantErr %v", err, tt.wantErr)
				return
			}
			if !reflect.DeepEqual(got, tt.want) {
				t.Errorf("processSeriesLine() got = %v, want %v", got, tt.want)
			}
		})
	}
}
