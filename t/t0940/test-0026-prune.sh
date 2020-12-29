#!/bin/sh

# Test crypto on "git-prune"

test_expect_success 'setup' '
	cp -a "$COMMON_GITDIR" bare.git
'

test_expect_success 'prune loose objects' '
	(
		cd bare.git &&
		find objects -type f >../before-prune.list &&
		git tag -d v1 &&
		git tag -d v3 &&
		git prune --expire=now &&
		find objects -type f >../after-prune.list
	) &&
	! test_cmp  before-prune.list after-prune.list
'
