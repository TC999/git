#!/bin/sh

# Test crypto on "git-blame"

test_expect_success 'blame on README.txt' '
	git -C "$COMMON_GITDIR" blame README.txt |
		make_user_friendly_and_stable_output >actual &&
	cat >expect <<-EOF &&
	^<COMMIT-C> (A U Thor 2005-04-07 15:13:13 -0700 1) Commit-A
	^<COMMIT-C> (A U Thor 2005-04-07 15:13:13 -0700 2) Commit-B
	^<COMMIT-C> (A U Thor 2005-04-07 15:13:13 -0700 3) Commit-C
	<COMMIT-F> (A U Thor 2005-04-07 15:16:13 -0700 4) Commit-D
	<COMMIT-F> (A U Thor 2005-04-07 15:16:13 -0700 5) Commit-E
	<COMMIT-F> (A U Thor 2005-04-07 15:16:13 -0700 6) Commit-F
	EOF
	test_cmp expect actual
'

test_expect_success 'annotate on README.txt' '
	git -C "$COMMON_GITDIR" annotate README.txt |
		make_user_friendly_and_stable_output >actual &&
	cat >expect <<-EOF &&
	<COMMIT-C>    ( A U Thor    2005-04-07 15:13:13 -0700    1)Commit-A
	<COMMIT-C>    ( A U Thor    2005-04-07 15:13:13 -0700    2)Commit-B
	<COMMIT-C>    ( A U Thor    2005-04-07 15:13:13 -0700    3)Commit-C
	<COMMIT-F>    ( A U Thor    2005-04-07 15:16:13 -0700    4)Commit-D
	<COMMIT-F>    ( A U Thor    2005-04-07 15:16:13 -0700    5)Commit-E
	<COMMIT-F>    ( A U Thor    2005-04-07 15:16:13 -0700    6)Commit-F
	EOF
	test_cmp expect actual
'
