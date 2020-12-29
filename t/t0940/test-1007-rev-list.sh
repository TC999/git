#!/bin/sh

# Test crypto on "git-rev-list"

test_expect_success 'rev-list master..topic/1' '
	git -C "$COMMON_GITDIR" rev-list master..topic/1 |
		make_user_friendly_and_stable_output >actual &&
	cat >expect <<-EOF &&
	<COMMIT-G>
	EOF
	test_cmp expect actual
'

test_expect_success 'rev-list v3...master' '
	git -C "$COMMON_GITDIR" rev-list v3...master |
		make_user_friendly_and_stable_output >actual &&
	cat >expect <<-EOF &&
	<COMMIT-F>
	<COMMIT-E>
	EOF
	test_cmp expect actual
'
