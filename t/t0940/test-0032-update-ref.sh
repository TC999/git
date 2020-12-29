#!/bin/sh

# Test crypto on "git-update-ref"

test_expect_success 'setup' '
	cp -a "$COMMON_GITDIR" bare.git
'
	
test_expect_success 'git update-ref' '
	(
		cd bare.git &&
		git update-ref -d refs/tags/v1 &&
		git update-ref -d refs/tags/v2 &&
		git update-ref -d refs/tags/v3 &&
		git update-ref -d refs/tags/v4 &&
		git show-ref
	) | make_user_friendly_and_stable_output >actual &&
	cat >expect <<-EOF &&
	<COMMIT-F> refs/heads/master
	<COMMIT-G> refs/heads/topic/1
	EOF
	test_cmp expect actual
'

test_expect_success 'git update-ref --stdin' '
	(
		cd bare.git &&
		git update-ref --stdin <<-EOF &&
			update refs/heads/master $E $F
			create refs/heads/next $F
			delete refs/heads/topic/1
			EOF
		git show-ref
	) | make_user_friendly_and_stable_output >actual &&
	cat >expect <<-EOF &&
	<COMMIT-E> refs/heads/master
	<COMMIT-F> refs/heads/next
	EOF
	test_cmp expect actual
'
