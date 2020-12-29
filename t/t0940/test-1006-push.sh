#!/bin/sh

# Test crypto on "git-push"

test_expect_success 'push encrypted repo to normal repo' '
	cp -a "$COMMON_GITDIR" encrypt.git &&
	git init --bare normal.git &&
	(
		cd encrypt.git &&
		git push ../normal.git --mirror
	)
'

test_expect_success 'run fsck on normal repo' '
	git -C normal.git fsck
'

test_expect_success 'check log of master' '
	git -C normal.git log --oneline |
		make_user_friendly_and_stable_output >actual &&
	cat >expect <<-EOF &&
	<COMMIT-F> Commit-F
	<COMMIT-C> Commit-C
	EOF
	test_cmp expect actual
'
