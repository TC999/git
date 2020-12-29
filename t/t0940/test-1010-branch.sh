#!/bin/sh

# Test crypto on "git-branch"

test_expect_success 'setup' '
	cp -R "$COMMON_GITDIR" bare.git
'

test_expect_success 'create new branch' '
	git -C bare.git branch topic/2 main
'

test_expect_success 'branch' '
	git -C bare.git branch >actual &&
	cat >expect <<-EOF &&
	* main
	  topic/1
	  topic/2
	EOF
	test_cmp expect actual
'

test_expect_success 'branch -v' '
	git -C bare.git branch -v |
		make_user_friendly_and_stable_output >actual &&
	cat >expect <<-EOF &&
	* main <COMMIT-F> Commit-F
	 topic/1 <COMMIT-G> Commit-G
	 topic/2 <COMMIT-F> Commit-F
	EOF
	test_cmp expect actual
'
