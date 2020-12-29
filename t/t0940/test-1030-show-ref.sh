#!/bin/sh

# Test crypto on "git-show-ref"

test_expect_success 'git show-ref' '
	git -C "$COMMON_GITDIR" show-ref |
		make_user_friendly_and_stable_output >actual &&
	cat >expect <<-EOF &&
	<COMMIT-F> refs/heads/master
	<COMMIT-G> refs/heads/topic/1
	<TAG-1> refs/tags/v1
	<TAG-2> refs/tags/v2
	<TAG-3> refs/tags/v3
	<TAG-4> refs/tags/v4
	EOF
	test_cmp expect actual
'

test_expect_success 'git show-ref --verify refs/heads/master' '
	git -C "$COMMON_GITDIR" show-ref --head --dereference |
		make_user_friendly_and_stable_output >actual &&
	cat >expect <<-EOF &&
	<COMMIT-F> HEAD
	<COMMIT-F> refs/heads/master
	<COMMIT-G> refs/heads/topic/1
	<TAG-1> refs/tags/v1
	<COMMIT-B> refs/tags/v1^{}
	<TAG-2> refs/tags/v2
	<COMMIT-C> refs/tags/v2^{}
	<TAG-3> refs/tags/v3
	<COMMIT-E> refs/tags/v3^{}
	<TAG-4> refs/tags/v4
	<COMMIT-F> refs/tags/v4^{}
	EOF
	test_cmp expect actual
'
