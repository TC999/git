#!/bin/sh

# Test crypto on "git-tag" and "git-verify-tag"

test_expect_success 'setup' '
	cp -a "$COMMON_GITDIR" bare.git
'

test_expect_success 'git tag -l' '
	git -C bare.git tag -l |
		make_user_friendly_and_stable_output >actual &&
	cat >expect <<-EOF &&
	v1
	v2
	v3
	v4
	EOF
	test_cmp expect actual
'

test_expect_success 'git tag -l -n1' '
	git -C bare.git tag -l -n1 |
		make_user_friendly_and_stable_output >actual &&
	cat >expect <<-EOF &&
	v1 v1
	v2 v2
	v3 v3
	v4 v4
	EOF
	test_cmp expect actual
'

test_expect_success GPG 'create signed tags' '
	(
		cd bare.git &&
		test_tick &&
		git tag -s -m "v1 signed" v1.s v1 &&
		git tag -s -m "v2 signed" v2.s v2 &&
		git tag -s -m "v3 signed" v3.s v3 &&
		git tag -s -m "v4 signed" v4.s v4
	)
'

test_expect_success GPG 'call git-tag to verify signed tags' '
	(
		cd bare.git &&
		git tag -v \
			v1.s \
			v2.s \
			v3.s \
			v4.s
	)
'

test_expect_success GPG 'call git-verify-tag to verify signed tags' '
	(
		cd bare.git &&
		git verify-tag -v \
			v1.s \
			v2.s \
			v3.s \
			v4.s
	)
'

test_expect_success GPG 'show signed tags' '
	git -C bare.git show v1.s |
		make_user_friendly_and_stable_output >actual &&
	grep "BEGIN PGP SIGNATURE" actual
'
