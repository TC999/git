#!/bin/sh

# Test crypto on "git-fetch"

test_expect_success 'fetch repo with encrypt packfile' '
	(
		git init workdir &&
		cd workdir &&
		git remote add origin "$COMMON_GITDIR" &&
		git fetch &&
		git merge --ff-only origin/master
	)
'

test_expect_success 'run fsck on workdir' '
	git -C workdir fsck
'

test_expect_success 'check log of master' '
	git -C workdir log --oneline |
		make_user_friendly_and_stable_output >actual &&
	cat >expect <<-EOF &&
	<COMMIT-F> Commit-F
	<COMMIT-C> Commit-C
	EOF
	test_cmp expect actual
'
