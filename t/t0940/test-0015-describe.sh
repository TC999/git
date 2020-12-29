#!/bin/sh

# Test crypto on "git-describe"

test_expect_success 'describe master' '
	git -C "$COMMON_GITDIR" describe master >actual &&
	cat >expect <<-EOF &&
	v4
	EOF
	test_cmp expect actual
'

test_expect_success 'describe topic/1' '
	git -C "$COMMON_GITDIR" describe topic/1 |
		make_user_friendly_and_stable_output >actual &&
	cat >expect <<-EOF &&
	v4-1-g<COMMIT-G>
	EOF
	test_cmp expect actual
'
