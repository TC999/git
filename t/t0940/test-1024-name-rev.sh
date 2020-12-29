#!/bin/sh

# Test crypto on "git-name-rev"

test_expect_success 'setup' '
	cp -R "$COMMON_GITDIR" bare.git
'

test_expect_success 'git name-rev main' '
	(
		cd bare.git &&
		git name-rev main
	) >actual &&
	cat >expect <<-EOF &&
	main tags/v4^0
	EOF
	test_cmp expect actual
'

test_expect_success 'name-rev on deleted tag v3' '
	(
		cd bare.git &&
		tag=$(git rev-parse v3^{commit}) &&
		git tag -d v3 >/dev/null 2>&1 &&
		git name-rev $tag
	) | make_user_friendly_and_stable_output >actual &&
	cat >expect <<-EOF &&
	<COMMIT-E> undefined
	EOF
	test_cmp expect actual
'
