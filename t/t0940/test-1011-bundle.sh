#!/bin/sh

# Test crypto on "git-bundle"

test_expect_success 'setup' '
	cp -R "$COMMON_GITDIR" bare.git
'

test_expect_success 'create unencrypted bundle from main' '
	git -C "$COMMON_GITDIR" bundle create \
		"$(pwd)/1.bundle" \
		main &&
	test -f 1.bundle
'

test_expect_failure 'clone from unencrypted bundle' '
	git clone --mirror 1.bundle repo1.git &&
	git -C repo1.git show-ref |
		make_user_friendly_and_stable_output >actual &&
	cat >expect <<-EOF &&
		<COMMIT-F> refs/heads/main
		EOF
	test_cmp expect actual
'

test_expect_success 'create additional unencrypted bundle' '
	git -C "$COMMON_GITDIR" bundle create \
		"$(pwd)/2.bundle" \
		--all --not main &&
	test -f 2.bundle
'

test_expect_failure 'fetch from additional bundle' '
	(
		cd repo1.git &&
		git fetch ../2.bundle "+refs/*:refs/*"
	) &&
	git -C repo1.git show-ref |
		make_user_friendly_and_stable_output >actual &&
	cat >expect <<-EOF &&
	<COMMIT-F> refs/heads/main
	<COMMIT-G> refs/heads/topic/1
	<TAG-1> refs/tags/v1
	<TAG-2> refs/tags/v2
	<TAG-3> refs/tags/v3
	<TAG-4> refs/tags/v4
	EOF
	test_cmp expect actual
'

###################################
test_expect_failure 'create encrypted bundle from main' '
	git -C "$COMMON_GITDIR" bundle create \
		--encrypt \
		"$(pwd)/3.bundle" \
		topic/1 &&
	test -f 3.bundle
'

test_expect_success 'cannot clone from encrypted bundle without crypto settings' '
	create_bare_repo repo2.git &&
	(
		cd repo2.git &&
		test_must_fail git fetch ../3.bundle "+refs/heads/*:refs/heads/*"
	)
'

test_expect_failure 'fetch from encrypted bundle' '
	(
		cd repo2.git &&
		git config agit.crypto.enabled 1 &&
		git config agit.crypto.secret c2VjcmV0LXRva2VuMTIzNA== &&
		git config agit.crypto.nonce random_nonce &&
		git fetch ../3.bundle "+refs/heads/*:refs/heads/*"
	) &&
	git -C repo2.git show-ref |
		make_user_friendly_and_stable_output >actual &&
	cat >expect <<-EOF &&
	<COMMIT-G> refs/heads/topic/1
	EOF
	test_cmp expect actual
'

test_expect_failure 'create additional encrypted bundle' '
	git -C "$COMMON_GITDIR" bundle create \
		--encrypt \
		"$(pwd)/4.bundle" \
		--tags --not topic/1 &&
	test -f 4.bundle
'

test_expect_failure 'fetch from additional encrypted bundle' '
	(
		cd repo2.git &&
		git fetch ../4.bundle "+refs/*:refs/*"
	) &&
	git -C repo2.git show-ref |
		make_user_friendly_and_stable_output >actual &&
	cat >expect <<-EOF &&
	<COMMIT-G> refs/heads/topic/1
	<TAG-1> refs/tags/v1
	<TAG-2> refs/tags/v2
	<TAG-3> refs/tags/v3
	<TAG-4> refs/tags/v4
	EOF
	test_cmp expect actual
'
