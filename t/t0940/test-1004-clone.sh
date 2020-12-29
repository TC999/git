#!/bin/sh

# Test crypto on "git-clone"

test_expect_failure 'clone from common gitdir' '
	git clone --no-local "$COMMON_GITDIR" workdir
'

test_expect_failure 'run fsck on workdir' '
	git -C workdir fsck
'

test_expect_failure 'check log of main' '
	git -C workdir log --oneline |
		make_user_friendly_and_stable_output >actual &&
	cat >expect <<-EOF &&
	<COMMIT-F> Commit-F
	<COMMIT-C> Commit-C
	EOF
	test_cmp expect actual
'
