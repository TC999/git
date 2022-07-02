package agit_release

import "testing"

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
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			if got := TrimTopicPrefixNumber(tt.args.topicName); got != tt.want {
				t.Errorf("TrimTopicPrefixNumber() = %v, want %v", got, tt.want)
			}
		})
	}
}
