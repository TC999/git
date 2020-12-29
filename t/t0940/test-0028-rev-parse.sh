#!/bin/sh

# Test crypto on "git-rev-parse"

test_expect_success 'git rev-parse master' '
	(
		cd "$COMMON_GITDIR" &&
		git rev-parse master
	) | make_user_friendly_and_stable_output >actual &&
	cat >expect <<-EOF &&
		<COMMIT-F>
		EOF
	test_cmp expect actual
'

test_expect_success 'git rev-parse v1^{commit}' '
	(
		cd "$COMMON_GITDIR" &&
		git rev-parse v1^{commit} 
	) | make_user_friendly_and_stable_output >actual &&
	cat >expect <<-EOF &&
	<COMMIT-B>
	EOF
	test_cmp expect actual
'

test_expect_success 'git rev-parse v2^{commit}' '
	(
		cd "$COMMON_GITDIR" &&
		git rev-parse v3^{commit} 
	) | make_user_friendly_and_stable_output >actual &&
	cat >expect <<-EOF &&
	<COMMIT-E>
	EOF
	test_cmp expect actual
'
