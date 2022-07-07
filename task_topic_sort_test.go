package agit_release

import (
	"reflect"
	"testing"
)

func Test_sortNoDependTopics(t *testing.T) {
	type args struct {
		noDependTopics []*dependDesc
	}
	var tests = []struct {
		name    string
		args    args
		want    []*dependDesc
		wantErr bool
	}{
		{
			//0
			//1
			//3:  0
			//5:  1
			//4:  2
			//2:  3
			name: "common_depend",
			args: args{
				noDependTopics: []*dependDesc{
					{
						CurrentIndex: 3,
						DependIndex:  0,
					},
					{
						CurrentIndex: 5,
						DependIndex:  1,
					},
					{
						CurrentIndex: 4,
						DependIndex:  2,
					},
					{
						CurrentIndex: 2,
						DependIndex:  3,
					},
				},
			},
			want: []*dependDesc{
				{
					CurrentIndex: 3,
					DependIndex:  0,
				},
				{
					CurrentIndex: 2,
					DependIndex:  3,
				},
				{
					CurrentIndex: 4,
					DependIndex:  2,
				},
				{
					CurrentIndex: 5,
					DependIndex:  1,
				},
			},
			wantErr: false,
		},
		{
			//0
			//1: 4
			//2
			//3: 1
			//4: 0
			//5
			name: "common_depends2",
			args: args{
				noDependTopics: []*dependDesc{
					{
						CurrentIndex: 4,
						DependIndex:  0,
					},
					{
						CurrentIndex: 3,
						DependIndex:  1,
					},
					{
						CurrentIndex: 1,
						DependIndex:  4,
					},
				},
			},
			want: []*dependDesc{
				{
					CurrentIndex: 4,
					DependIndex:  0,
				},
				{
					CurrentIndex: 1,
					DependIndex:  4,
				},
				{
					CurrentIndex: 3,
					DependIndex:  1,
				},
			},
			wantErr: false,
		},
		{
			//0
			//1
			//2: 5
			//3: 2
			//4
			//5: 3
			name: "circular_reference",
			args: args{
				noDependTopics: []*dependDesc{
					{
						CurrentIndex: 2,
						DependIndex:  5,
					},
					{
						CurrentIndex: 3,
						DependIndex:  2,
					},
					{
						CurrentIndex: 5,
						DependIndex:  3,
					},
				},
			},
			want:    nil,
			wantErr: true,
		},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			if got, err := sortDependTopics(tt.args.noDependTopics); !reflect.DeepEqual(got, tt.want) && (err != nil) != tt.wantErr {
				t.Errorf("sortDependTopics() = %v, want %v", got, tt.want)
			}
		})
	}
}
