package patchwork

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

func TestTaskTopicSort_sortDepend(t1 *testing.T) {
	type args struct {
		taskContext *TaskContext
	}
	tests := []struct {
		name           string
		args           args
		wantErr        bool
		wantTopicArray []*Topic
		wantErrMsg     string
	}{
		{
			//0a
			//1b
			//2c:b1
			//3d:f5
			//4e:a0
			//5f

			//c-b
			//d-f
			//e-a
			name: "one_layer_successfully",
			args: args{
				taskContext: &TaskContext{
					topics: []*Topic{
						{
							TopicName:   "a",
							DependIndex: -1,
							BranchType:  0,
							GitBranch: &Branch{
								BranchName: "a",
							},
						},
						{
							TopicName:   "b",
							DependIndex: -1,
							BranchType:  0,
							GitBranch: &Branch{
								BranchName: "b",
							},
						},
						{
							TopicName:   "c",
							DependIndex: 1,
							BranchType:  0,
							GitBranch: &Branch{
								BranchName: "c",
							},
						},
						{
							TopicName:   "d",
							DependIndex: 5,
							BranchType:  0,
							GitBranch: &Branch{
								BranchName: "d",
							},
						},
						{
							TopicName:   "e",
							DependIndex: 0,
							BranchType:  0,
							GitBranch: &Branch{
								BranchName: "e",
							},
						},
						{
							TopicName:   "f",
							DependIndex: -1,
							BranchType:  0,
							GitBranch: &Branch{
								BranchName: "f",
							},
						},
					},
				},
			},
			wantErr: false,
			wantTopicArray: []*Topic{
				{
					TopicName:   "a",
					DependIndex: -1,
					BranchType:  0,
					GitBranch: &Branch{
						BranchName: "a",
					},
				},
				{
					TopicName:   "b",
					DependIndex: -1,
					BranchType:  0,
					GitBranch: &Branch{
						BranchName: "b",
					},
				},
				{
					TopicName:   "f",
					DependIndex: -1,
					BranchType:  0,
					GitBranch: &Branch{
						BranchName: "f",
					},
				},
				{
					TopicName:   "c",
					DependIndex: 1,
					BranchType:  0,
					GitBranch: &Branch{
						BranchName: "c",
					},
				},
				{
					TopicName:   "d",
					DependIndex: 2,
					BranchType:  0,
					GitBranch: &Branch{
						BranchName: "d",
					},
				},
				{
					TopicName:   "e",
					DependIndex: 0,
					BranchType:  0,
					GitBranch: &Branch{
						BranchName: "e",
					},
				},
			},
		},
		{
			//0a
			//1b
			//2c
			//3d:b
			//4e:c
			//5f:d
			name: "f-d-b_e-c",
			args: args{
				taskContext: &TaskContext{
					topics: []*Topic{
						{
							TopicName:   "a",
							DependIndex: -1,
							BranchType:  0,
							GitBranch: &Branch{
								BranchName: "a",
							},
						},
						{
							TopicName:   "b",
							DependIndex: -1,
							BranchType:  0,
							GitBranch: &Branch{
								BranchName: "b",
							},
						},
						{
							TopicName:   "c",
							DependIndex: -1,
							BranchType:  0,
							GitBranch: &Branch{
								BranchName: "c",
							},
						},
						{
							TopicName:   "d",
							DependIndex: 1,
							BranchType:  0,
							GitBranch: &Branch{
								BranchName: "d",
							},
						},
						{
							TopicName:   "e",
							DependIndex: 2,
							BranchType:  0,
							GitBranch: &Branch{
								BranchName: "e",
							},
						},
						{
							TopicName:   "f",
							DependIndex: 3,
							BranchType:  0,
							GitBranch: &Branch{
								BranchName: "f",
							},
						},
					},
				},
			},
			wantErr: false,
			wantTopicArray: []*Topic{
				{
					TopicName:   "a",
					DependIndex: -1,
					GitBranch: &Branch{
						BranchName: "a",
					},
				},
				{
					TopicName:   "b",
					DependIndex: -1,
					GitBranch: &Branch{
						BranchName: "b",
					},
				},
				{
					TopicName:   "c",
					DependIndex: -1,
					GitBranch: &Branch{
						BranchName: "c",
					},
				},
				{
					TopicName:   "d",
					DependIndex: 1,
					GitBranch: &Branch{
						BranchName: "d",
					},
				},
				{
					TopicName:   "f",
					DependIndex: 3,
					GitBranch: &Branch{
						BranchName: "f",
					},
				},
				{
					TopicName:   "e",
					DependIndex: 2,
					GitBranch: &Branch{
						BranchName: "e",
					},
				},
			},
		},
		{
			//0a
			//1b:e
			//2c
			//3d:b
			//4e:d
			//5f:

			//e-d-b-e circular dependency
			name: "e-d-b-e_circular_dependency",
			args: args{
				taskContext: &TaskContext{
					topics: []*Topic{
						{
							TopicName:   "a",
							DependIndex: -1,
							BranchType:  0,
							GitBranch: &Branch{
								BranchName: "a",
							},
						},
						{
							TopicName:   "b",
							DependIndex: 4,
							BranchType:  0,
							GitBranch: &Branch{
								BranchName: "b",
							},
						},
						{
							TopicName:   "c",
							DependIndex: -1,
							BranchType:  0,
							GitBranch: &Branch{
								BranchName: "c",
							},
						},
						{
							TopicName:   "d",
							DependIndex: 1,
							BranchType:  0,
							GitBranch: &Branch{
								BranchName: "d",
							},
						},
						{
							TopicName:   "e",
							DependIndex: 3,
							BranchType:  0,
							GitBranch: &Branch{
								BranchName: "e",
							},
						},
						{
							TopicName:   "f",
							DependIndex: -1,
							BranchType:  0,
							GitBranch: &Branch{
								BranchName: "f",
							},
						},
					},
				},
			},
			wantErr:        true,
			wantTopicArray: nil,
			wantErrMsg:     "circular reference",
		},
		{
			//0a
			//1b
			//2c:b
			//3d:b
			//4e:b
			//5f:

			//c-b
			//d-b
			//e-b

			name: "c-b_d-b_e-b_multiple_to_one",
			args: args{
				taskContext: &TaskContext{
					topics: []*Topic{
						{
							TopicName:   "a",
							DependIndex: -1,
							BranchType:  0,
							GitBranch: &Branch{
								BranchName: "a",
							},
						},
						{
							TopicName:   "b",
							DependIndex: -1,
							BranchType:  0,
							GitBranch: &Branch{
								BranchName: "b",
							},
						},
						{
							TopicName:   "c",
							DependIndex: 1,
							BranchType:  0,
							GitBranch: &Branch{
								BranchName: "c",
							},
						},
						{
							TopicName:   "d",
							DependIndex: 1,
							BranchType:  0,
							GitBranch: &Branch{
								BranchName: "d",
							},
						},
						{
							TopicName:   "e",
							DependIndex: 1,
							BranchType:  0,
							GitBranch: &Branch{
								BranchName: "e",
							},
						},
						{
							TopicName:   "f",
							DependIndex: -1,
							BranchType:  0,
							GitBranch: &Branch{
								BranchName: "f",
							},
						},
					},
				},
			},
			wantErr: false,
			wantTopicArray: []*Topic{
				{
					TopicName:   "a",
					DependIndex: -1,
					BranchType:  0,
					GitBranch: &Branch{
						BranchName: "a",
					},
				},
				{
					TopicName:   "b",
					DependIndex: -1,
					BranchType:  0,
					GitBranch: &Branch{
						BranchName: "b",
					},
				},
				{
					TopicName:   "f",
					DependIndex: -1,
					BranchType:  0,
					GitBranch: &Branch{
						BranchName: "f",
					},
				},
				{
					TopicName:   "c",
					DependIndex: 1,
					BranchType:  0,
					GitBranch: &Branch{
						BranchName: "c",
					},
				},
				{
					TopicName:   "d",
					DependIndex: 1,
					BranchType:  0,
					GitBranch: &Branch{
						BranchName: "d",
					},
				},
				{
					TopicName:   "e",
					DependIndex: 1,
					BranchType:  0,
					GitBranch: &Branch{
						BranchName: "e",
					},
				},
			},
		},
		{
			//0a
			//1b:d
			//2c:b
			//3d:
			//4e:b
			//5f:d
			name: "c-b_e-b_f-b_depend_index_changed",
			args: args{
				taskContext: &TaskContext{
					topics: []*Topic{
						{
							TopicName:   "a",
							DependIndex: -1,
							BranchType:  0,
							GitBranch: &Branch{
								BranchName: "a",
							},
						},
						{
							TopicName:   "b",
							DependIndex: 3,
							BranchType:  0,
							GitBranch: &Branch{
								BranchName: "b",
							},
						},
						{
							TopicName:   "c",
							DependIndex: 1,
							BranchType:  0,
							GitBranch: &Branch{
								BranchName: "c",
							},
						},
						{
							TopicName:   "d",
							DependIndex: -1,
							BranchType:  0,
							GitBranch: &Branch{
								BranchName: "d",
							},
						},
						{
							TopicName:   "e",
							DependIndex: 1,
							BranchType:  0,
							GitBranch: &Branch{
								BranchName: "e",
							},
						},
						{
							TopicName:   "f",
							DependIndex: 3,
							BranchType:  0,
							GitBranch: &Branch{
								BranchName: "f",
							},
						},
					},
				},
			},
			wantErr: false,
			wantTopicArray: []*Topic{
				{
					TopicName:   "a",
					DependIndex: -1,
					BranchType:  0,
					GitBranch: &Branch{
						BranchName: "a",
					},
				},
				{
					TopicName:   "d",
					DependIndex: -1,
					BranchType:  0,
					GitBranch: &Branch{
						BranchName: "d",
					},
				},
				{
					TopicName:   "b",
					DependIndex: 1,
					BranchType:  0,
					GitBranch: &Branch{
						BranchName: "b",
					},
				},
				{
					TopicName:   "c",
					DependIndex: 2,
					BranchType:  0,
					GitBranch: &Branch{
						BranchName: "c",
					},
				},
				{
					TopicName:   "e",
					DependIndex: 2,
					BranchType:  0,
					GitBranch: &Branch{
						BranchName: "e",
					},
				},
				{
					TopicName:   "f",
					DependIndex: 1,
					BranchType:  0,
					GitBranch: &Branch{
						BranchName: "f",
					},
				},
			},
		},
	}
	for _, tt := range tests {
		t1.Run(tt.name, func(t1 *testing.T) {
			t := &TaskTopicSort{}
			err := t.sortDepend(tt.args.taskContext)
			if (err != nil) != tt.wantErr {
				t1.Errorf("sortDepend() error = %v, wantErr %v", err, tt.wantErr)
			}

			if err != nil && tt.wantErrMsg != err.Error() {
				t1.Errorf("error message invalid, want: %s, but got: %s", tt.wantErrMsg, err.Error())
			}

			if err == nil && !reflect.DeepEqual(tt.wantTopicArray, tt.args.taskContext.topics) {
				t1.Errorf("wantTopicArray not equal")
			}

			// Not have error then do the check
			if err == nil {
				// Check dependency index must before the current index
				for index, topic := range tt.args.taskContext.topics {
					if topic.DependIndex >= index {
						t1.Errorf("the topic: '%s' dependency index: %d invalid", topic.GitBranch.BranchName, index)
					}
				}
			}
		})
	}
}
