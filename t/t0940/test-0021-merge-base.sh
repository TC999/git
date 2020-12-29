#!/bin/sh

# Test crypto on "git-merge-base"

test_expect_success 'merge-basse of v4 topic-1' '
	git -C "$COMMON_GITDIR" merge-base -a v4 topic/1 |
		make_user_friendly_and_stable_output >actual &&
	cat >expect <<-EOF &&
	<COMMIT-F>
	EOF
	test_cmp expect actual
'
